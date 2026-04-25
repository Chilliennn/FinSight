'use strict';

const { DocumentProcessorServiceClient } = require('@google-cloud/documentai').v1;
const { getDocumentBuffer } = require('../../data/storage/r2Storage');

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value != null && String(value).trim() !== '') {
      return String(value).trim();
    }
  }
  return null;
}

const DEFAULT_CREDENTIAL_OBJECT_KEY = firstNonEmpty(
  process.env.GCP_SERVICE_ACCOUNT_R2_KEY,
  'vps-student-30f13-66848866f70b.json',
);

async function loadCredentialMaterial() {
  const credentialBuffer = await getDocumentBuffer(DEFAULT_CREDENTIAL_OBJECT_KEY);
  return {
    source: 'r2',
    credentialFile: null,
    credentials: JSON.parse(credentialBuffer.toString('utf8')),
  };
}

let credentialMaterialPromise = null;

function getCredentialMaterial() {
  if (!credentialMaterialPromise) {
    credentialMaterialPromise = loadCredentialMaterial();
  }

  return credentialMaterialPromise;
}

const LOCATION = firstNonEmpty(
  process.env.GCP_LOCATION,
  'asia-southeast1',
);
const BANK_STATEMENT_LOCATION = firstNonEmpty(
  process.env.GCP_LOCATION2,
  LOCATION,
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

const clientInstances = new Map();

function getProcessorLocation(processorKey) {
  if (processorKey === 'bank_statement') {
    return BANK_STATEMENT_LOCATION;
  }

  return LOCATION;
}

function getApiEndpoint(location) {
  if (!location) {
    return undefined;
  }

  return `${location}-documentai.googleapis.com`;
}

async function getClient(processorKey) {
  const location = getProcessorLocation(processorKey);
  const { credentials } = await getCredentialMaterial();
  const projectId = firstNonEmpty(process.env.GCP_PROJECT_ID, credentials?.project_id);
  if (!projectId) {
    throw new Error('Document AI project ID is not configured');
  }

  const clientKey = `${location || 'default'}:${projectId}`;

  if (!clientInstances.has(clientKey)) {
    const clientOptions = {
      apiEndpoint: getApiEndpoint(location),
      credentials,
    };

    clientInstances.set(clientKey, {
      client: new DocumentProcessorServiceClient(clientOptions),
      projectId,
    });
  }

  return clientInstances.get(clientKey);
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

function scoreDocumentTypeSignals(text, entities = []) {
  const normalized = normalizeText(text).toLowerCase();
  const entityTypes = entities
    .map((entity) => String(entity.type || '').toLowerCase())
    .filter(Boolean);

  const scores = {
    bank_statement: 0,
    invoice: 0,
    receipt: 0,
  };

  if (entityTypes.some((type) => type.includes('bank'))) {
    scores.bank_statement += 8;
  }

  if (
    /\b(statement|opening balance|closing balance|available balance|withdrawal|deposit)\b/.test(
      normalized,
    )
  ) {
    scores.bank_statement += 8;
  }

  if (/\b(debit|credit)\b/.test(normalized)) {
    scores.bank_statement += 4;
  }

  if (
    entityTypes.some((type) => type === 'invoice_id' || type === 'invoice_date')
  ) {
    scores.invoice += 6;
  }

  if (
    /\b(invoice no|invoice number|date of issue|seller|client|bill to|ship to|amount due|due date)\b/.test(
      normalized,
    )
  ) {
    scores.invoice += 6;
  }

  if (/\b(vat|gross worth|net worth|tax id|iban|swift|account no)\b/.test(normalized)) {
    scores.invoice += 5;
  }

  if (/\b(unit price|u\.price|subtotal|sub total|grand total)\b/.test(normalized)) {
    scores.invoice += 3;
  }

  if (/\binvoice\b/.test(normalized)) {
    scores.invoice += 2;
  }

  if (
    entityTypes.some(
      (type) =>
        type.includes('receipt') ||
        type.includes('supplier_name') ||
        type.includes('merchant_name'),
    )
  ) {
    scores.receipt += 4;
  }

  if (/\breceipt\b|\bcash bill\b/.test(normalized)) {
    scores.receipt += 6;
  }

  if (/\bcash\b/.test(normalized)) {
    scores.receipt += 4;
  }

  if (/\bchange\b/.test(normalized)) {
    scores.receipt += 4;
  }

  if (/\bcashier\b|\boperator\b|\bmember\b/.test(normalized)) {
    scores.receipt += 4;
  }

  if (/\btoken no\b|\bstation id\b|\bpid:\s*pos\b|\bprint by\b/.test(normalized)) {
    scores.receipt += 5;
  }

  if (
    /\bgoods sold are not returnable\b|\bexchangeable\b|\bthank you\b|\bplease come again\b|\bstrictly no cash refund\b/.test(
      normalized,
    )
  ) {
    scores.receipt += 4;
  }

  if (/\bqty\(s\)\b|\bitem\(s\)\b|\brounded total\b|\brounding adjustment\b/.test(normalized)) {
    scores.receipt += 3;
  }

  if (scores.receipt > 0 && /\binvoice\b/.test(normalized) && /\bcash\b|\bchange\b/.test(normalized)) {
    scores.receipt += 3;
  }

  return scores;
}

function detectDocumentTypeFromText(text, entities = []) {
  const scores = scoreDocumentTypeSignals(text, entities);
  const ranked = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const [topType, topScore] = ranked[0] || ['unknown', 0];
  const [, secondScore] = ranked[1] || ['unknown', 0];

  if (!topScore || topScore < 4) {
    return 'unknown';
  }

  if (topScore === secondScore) {
    if (scores.receipt === topScore) return 'receipt';
    if (scores.invoice === topScore) return 'invoice';
    if (scores.bank_statement === topScore) return 'bank_statement';
  }

  return topType;
}

async function runProcessor({ buffer, mimeType, fileName, processorKey, processorId }) {
  const processorLocation = getProcessorLocation(processorKey);
  const { client, projectId } = await getClient(processorKey);
  const name = `projects/${projectId}/locations/${processorLocation}/processors/${processorId}`;

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
      `Document AI processDocument failed for processor "${processorKey}" at "${name}" with mimeType "${mimeType}": ${error.message}`,
    );
  }

  const document = result.document || {};
  const rawText = normalizeText(document.text || '');
  const entities = mapEntities(document);

  return {
    rawText,
    totalPages: Array.isArray(document.pages) ? document.pages.length : null,
    ocrRequired: mimeType !== 'application/pdf',
    extractionMethod: `document_ai_${processorKey}`,
    documentAi: {
      processorKey,
      processorName: name,
      entities,
      hints: buildHints(document, processorKey),
    },
  };
}

async function processDocumentWithDocumentAi({ buffer, mimeType, fileName }) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('Document buffer is empty');
  }

  const processor = chooseProcessor({ fileName, mimeType });
  const initialResult = await runProcessor({
    buffer,
    mimeType,
    fileName,
    processorKey: processor.key,
    processorId: processor.id,
  });
  const detectedDocumentType = detectDocumentTypeFromText(
    initialResult.rawText,
    initialResult.documentAi.entities,
  );

  const rerouteCandidates = {
    invoice: PROCESSOR_IDS.invoice,
    receipt: PROCESSOR_IDS.expense,
    bank_statement: PROCESSOR_IDS.bank_statement,
  };

  const targetProcessorKey =
    detectedDocumentType === 'receipt' ? 'expense' : detectedDocumentType;
  const targetProcessorId = rerouteCandidates[detectedDocumentType];

  if (
    targetProcessorKey &&
    targetProcessorId &&
    processor.key !== targetProcessorKey
  ) {
    try {
      return await runProcessor({
        buffer,
        mimeType,
        fileName,
        processorKey: targetProcessorKey,
        processorId: targetProcessorId,
      });
    } catch (error) {
      console.warn(
        `[documentAi.engine] reroute from ${processor.key} to ${targetProcessorKey} failed for "${fileName || 'document'}": ${error.message}`,
      );
    }
  }

  return initialResult;
}

function isConfigured() {
  return Boolean(Object.values(PROCESSOR_IDS).some(Boolean));
}

module.exports = {
  isConfigured,
  processDocumentWithDocumentAi,
};
