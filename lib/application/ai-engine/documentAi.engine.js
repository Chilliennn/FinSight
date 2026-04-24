'use strict';

const fs = require('fs');
const path = require('path');

const { DocumentProcessorServiceClient } = require('@google-cloud/documentai').v1;

const REPO_ROOT = path.resolve(__dirname, '../../..');
const DEFAULT_CREDENTIAL_FILE = path.join(
  REPO_ROOT,
  'vps-student-30f13-c8062f0a8126.json',
);

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value != null && String(value).trim() !== '') {
      return String(value).trim();
    }
  }
  return null;
}

function findCredentialFile() {
  const configuredPath = firstNonEmpty(
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    process.env.GOOGLE_SERVICE_ACCOUNT_FILE,
  );

  if (configuredPath && fs.existsSync(configuredPath)) {
    return configuredPath;
  }

  if (fs.existsSync(DEFAULT_CREDENTIAL_FILE)) {
    return DEFAULT_CREDENTIAL_FILE;
  }

  return null;
}

function loadCredentialMetadata(credentialFile) {
  if (!credentialFile) return {};

  try {
    return JSON.parse(fs.readFileSync(credentialFile, 'utf8'));
  } catch {
    return {};
  }
}

const credentialFile = findCredentialFile();
const credentialMetadata = loadCredentialMetadata(credentialFile);
const PROJECT_ID = firstNonEmpty(
  process.env.GCP_PROJECT_ID,
  credentialMetadata.project_id,
);
const LOCATION = firstNonEmpty(
  process.env.GCP_LOCATION,
  'asia-southeast1',
);
const PROCESSOR_IDS = {
  expense: firstNonEmpty(
    process.env.GCP_DOCUMENT_AI_EXPENSE_PROCESSOR_ID,
    process.env.DOCUMENT_AI_EXPENSE_PROCESSOR_ID,
  ),
  invoice: firstNonEmpty(
    process.env.GCP_DOCUMENT_AI_INVOICE_PROCESSOR_ID,
    process.env.DOCUMENT_AI_INVOICE_PROCESSOR_ID,
  ),
  bank_statement: firstNonEmpty(
    process.env.GCP_DOCUMENT_AI_BANK_STATEMENT_PROCESSOR_ID,
    process.env.DOCUMENT_AI_BANK_STATEMENT_PROCESSOR_ID,
  ),
  ocr: firstNonEmpty(
    process.env.GCP_DOCUMENT_AI_OCR_PROCESSOR_ID,
    process.env.DOCUMENT_AI_OCR_PROCESSOR_ID,
  ),
};

let clientInstance;

function getApiEndpoint() {
  if (!LOCATION) {
    return undefined;
  }

  return `${LOCATION}-documentai.googleapis.com`;
}

function getClient() {
  if (!PROJECT_ID) {
    throw new Error('Document AI project ID is not configured');
  }

  if (!clientInstance) {
    const clientOptions = {
      apiEndpoint: getApiEndpoint(),
    };

    if (credentialFile) {
      clientOptions.keyFilename = credentialFile;
    }

    clientInstance = new DocumentProcessorServiceClient(clientOptions);
  }

  return clientInstance;
}

function getTextFromAnchor(textAnchor, text) {
  if (!textAnchor?.textSegments?.length || !text) {
    return '';
  }

  return textAnchor.textSegments
    .map((segment) => {
      const startIndex = Number(segment.startIndex || 0);
      const endIndex = Number(segment.endIndex || 0);
      return text.slice(startIndex, endIndex);
    })
    .join('');
}

function normalizeText(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function parseDateValue(value) {
  if (!value) return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

function formatDateOnly(value) {
  if (!value) return null;
  const year = String(value.getUTCFullYear());
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function extractEntityValue(entity, text) {
  return firstNonEmpty(
    entity?.mentionText,
    entity?.normalizedValue?.text,
    entity?.normalizedValue?.moneyValue?.currencyCode,
    getTextFromAnchor(entity?.textAnchor, text),
  );
}

function getEntityList(document) {
  return Array.isArray(document?.entities) ? document.entities : [];
}

function mapEntities(document) {
  const text = document?.text || '';
  return getEntityList(document)
    .map((entity) => ({
      type: entity.type || null,
      confidence: typeof entity.confidence === 'number' ? entity.confidence : null,
      value: extractEntityValue(entity, text),
      normalizedMoney: entity.normalizedValue?.moneyValue || null,
    }))
    .filter((entity) => entity.type || entity.value);
}

function pickEntityValue(entities, patterns) {
  for (const pattern of patterns) {
    const match = entities.find((entity) => entity.type && pattern.test(entity.type));
    if (match?.value) {
      return match.value;
    }
  }
  return null;
}

function pickCompanyName(entities) {
  const exactNamePatterns = [
    /^supplier_name$/i,
    /^merchant_name$/i,
    /^vendor_name$/i,
    /^seller_name$/i,
    /^business_name$/i,
    /^company_name$/i,
  ];

  const nameLikePatterns = [
    /supplier.*name/i,
    /merchant.*name/i,
    /vendor.*name/i,
    /seller.*name/i,
    /business.*name/i,
    /company.*name/i,
  ];

  const genericPatterns = [
    /^supplier$/i,
    /^merchant$/i,
    /^vendor$/i,
    /^seller$/i,
    /^business$/i,
    /^company$/i,
  ];

  const blockedPatterns = [
    /address/i,
    /street/i,
    /postcode/i,
    /postal/i,
    /city/i,
    /state/i,
    /country/i,
    /phone/i,
    /fax/i,
    /email/i,
  ];

  const isAllowed = (entity) =>
    entity?.type &&
    entity.value &&
    !blockedPatterns.some((pattern) => pattern.test(entity.type));

  for (const patterns of [exactNamePatterns, nameLikePatterns, genericPatterns]) {
    for (const pattern of patterns) {
      const match = entities.find(
        (entity) => isAllowed(entity) && pattern.test(entity.type),
      );
      if (match?.value) {
        return match.value;
      }
    }
  }

  return null;
}

function pickCurrency(entities) {
  for (const entity of entities) {
    const currencyCode = entity.normalizedMoney?.currencyCode;
    if (currencyCode) {
      return currencyCode;
    }

    if (entity.type && /currency/i.test(entity.type) && entity.value) {
      return entity.value.toUpperCase();
    }
  }

  return null;
}

function buildHints(document, processorKey) {
  const entities = mapEntities(document);
  const companyName = pickCompanyName(entities);
  const rawInvoiceDate = pickEntityValue(entities, [
    /^invoice_date$/i,
    /^receipt_date$/i,
    /transaction_date/i,
    /purchase_date/i,
    /^date$/i,
  ]);
  const normalizedInvoiceDate = formatDateOnly(parseDateValue(rawInvoiceDate));

  const documentTypeHint =
    processorKey === 'expense'
      ? 'receipt'
      : processorKey === 'invoice'
      ? 'invoice'
      : processorKey === 'bank_statement'
      ? 'bank_statement'
      : null;

  return {
    documentType: documentTypeHint,
    companyName,
    invoiceDate: normalizedInvoiceDate,
    currency: pickCurrency(entities),
    entities: entities.slice(0, 20),
  };
}

function chooseProcessor({ fileName = '', mimeType = '' }) {
  const lowerName = String(fileName).toLowerCase();

  if (PROCESSOR_IDS.bank_statement && /\b(statement|bank)\b/.test(lowerName)) {
    return { key: 'bank_statement', id: PROCESSOR_IDS.bank_statement };
  }

  if (PROCESSOR_IDS.invoice && /invoice/.test(lowerName)) {
    return { key: 'invoice', id: PROCESSOR_IDS.invoice };
  }

  if (PROCESSOR_IDS.expense) {
    return { key: 'expense', id: PROCESSOR_IDS.expense };
  }

  if (PROCESSOR_IDS.ocr) {
    return { key: 'ocr', id: PROCESSOR_IDS.ocr };
  }

  if (PROCESSOR_IDS.invoice) {
    return { key: 'invoice', id: PROCESSOR_IDS.invoice };
  }

  if (PROCESSOR_IDS.bank_statement) {
    return { key: 'bank_statement', id: PROCESSOR_IDS.bank_statement };
  }

  throw new Error(
    `No Document AI processor is configured for ${mimeType || 'unknown file type'}`,
  );
}

function detectDocumentTypeFromText(text, entities = []) {
  const normalized = normalizeText(text).toLowerCase();
  const entityTypes = entities
    .map((entity) => String(entity.type || '').toLowerCase())
    .filter(Boolean);

  if (
    entityTypes.some((type) => type.includes('bank')) ||
    /\b(statement|opening balance|closing balance|available balance|debit|credit|withdrawal|deposit)\b/.test(
      normalized,
    )
  ) {
    return 'bank_statement';
  }

  if (
    entityTypes.some((type) => type === 'invoice_id' || type === 'invoice_date') ||
    /\b(invoice no|invoice number|date of issue|seller|client|vat|gross worth|net worth|tax id)\b/.test(
      normalized,
    )
  ) {
    return 'invoice';
  }

  if (
    entityTypes.some(
      (type) =>
        type.includes('receipt') ||
        type.includes('supplier_name') ||
        type.includes('merchant_name'),
    ) ||
    /\b(receipt|cash|change|cashier|operator|qty\(s\)|item\(s\)|strictly no cash refund)\b/.test(
      normalized,
    )
  ) {
    return 'receipt';
  }

  return 'unknown';
}

async function processDocumentWithDocumentAi({ buffer, mimeType, fileName }) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('Document buffer is empty');
  }

  const processor = chooseProcessor({ fileName, mimeType });
  const client = getClient();
  const name = `projects/${PROJECT_ID}/locations/${LOCATION}/processors/${processor.id}`;
  let result;

  try {
    [result] = await client.processDocument({
      name,
      rawDocument: {
        content: buffer.toString('base64'),
        mimeType,
      },
    });
  } catch (error) {
    throw new Error(
      `Document AI processDocument failed for processor "${processor.key}" at "${name}" with mimeType "${mimeType}": ${error.message}`,
    );
  }

  const document = result.document || {};
  const rawText = normalizeText(document.text || '');
  const entities = mapEntities(document);
  const detectedDocumentType = detectDocumentTypeFromText(rawText, entities);

  if (
    detectedDocumentType === 'invoice' &&
    processor.key !== 'invoice' &&
    PROCESSOR_IDS.invoice
  ) {
    const invoiceProcessor = {
      key: 'invoice',
      id: PROCESSOR_IDS.invoice,
    };
    const invoiceName = `projects/${PROJECT_ID}/locations/${LOCATION}/processors/${invoiceProcessor.id}`;
    let invoiceResult;

    try {
      [invoiceResult] = await client.processDocument({
        name: invoiceName,
        rawDocument: {
          content: buffer.toString('base64'),
          mimeType,
        },
      });
    } catch (error) {
      throw new Error(
        `Document AI invoice reroute failed for "${fileName || 'document'}": ${error.message}`,
      );
    }

    const reroutedDocument = invoiceResult.document || {};
    const reroutedText = normalizeText(reroutedDocument.text || '');

    return {
      rawText: reroutedText,
      totalPages: Array.isArray(reroutedDocument.pages)
        ? reroutedDocument.pages.length
        : null,
      ocrRequired: mimeType !== 'application/pdf',
      extractionMethod: 'document_ai_invoice',
      documentAi: {
        processorKey: 'invoice',
        processorName: invoiceName,
        entities: mapEntities(reroutedDocument),
        hints: buildHints(reroutedDocument, 'invoice'),
      },
    };
  }

  return {
    rawText,
    totalPages: Array.isArray(document.pages) ? document.pages.length : null,
    ocrRequired: mimeType !== 'application/pdf',
    extractionMethod: `document_ai_${processor.key}`,
    documentAi: {
      processorKey: processor.key,
      processorName: name,
      entities,
      hints: buildHints(document, processor.key),
    },
  };
}

function isConfigured() {
  return Boolean(PROJECT_ID && Object.values(PROCESSOR_IDS).some(Boolean));
}

module.exports = {
  isConfigured,
  processDocumentWithDocumentAi,
};
