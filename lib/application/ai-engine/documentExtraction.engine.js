'use strict';

const {
  DOCUMENT_EXTRACTION_SYSTEM_PROMPT,
  buildDocumentExtractionPrompt,
} = require('./prompts/documentExtractionPrompt');
const { client } = require('./openaiClient');

const ZAI_MODEL = process.env.ZAI_MODEL;
const DOCUMENT_EXTRACTION_ATTEMPT_TIMEOUT_MS = Number(
  process.env.DOCUMENT_EXTRACTION_ATTEMPT_TIMEOUT_MS ?? 55000,
);
const DOCUMENT_EXTRACTION_RETRY_TIMEOUT_MS = Number(
  process.env.DOCUMENT_EXTRACTION_RETRY_TIMEOUT_MS ?? 40000,
);
const USE_MOCK_AI = String(process.env.USE_MOCK_AI ?? 'false') === 'true';

if (!ZAI_MODEL) throw new Error('[documentExtraction.engine] ZAI_MODEL is not set');

const VALID_DOCUMENT_TYPES = ['invoice', 'receipt', 'bank_statement', 'contract', 'unknown'];
const VALID_RECORD_TYPES = ['income', 'expense', 'bank_transaction', 'invoice_payable', 'invoice_receivable'];
const VALID_DIRECTIONS = ['inflow', 'outflow'];
const MONTH_MAP = {
  january: '01',
  february: '02',
  march: '03',
  april: '04',
  may: '05',
  june: '06',
  july: '07',
  august: '08',
  september: '09',
  october: '10',
  november: '11',
  december: '12',
};

function parseOptionalDate(value, fieldName) {
  if (value == null || value === '') return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid ${fieldName}`);
  }
  return parsed;
}

function normalizeCurrency(value) {
  if (!value) return 'MYR';
  return String(value).trim().toUpperCase();
}

function withTimeout(promise, timeoutMs, label) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${label} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    clearTimeout(timeoutId);
  });
}

function stripCodeFences(text) {
  return String(text || '')
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();
}

function normalizeRawText(rawText) {
  return String(rawText || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function scoreLine(line) {
  let score = 0;
  if (/[A-Za-z]/.test(line)) score += 1;
  if (/\b(invoice|receipt|statement|supplier|vendor|bank|total|amount|subtotal|tax|due|date|payment|reference|balance|debit|credit|rm)\b/i.test(line)) {
    score += 4;
  }
  if (/rm\s?\d|\d+\.\d{2}|\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b/i.test(line)) {
    score += 3;
  }
  if (line.length >= 12 && line.length <= 140) score += 1;
  return score;
}

function compressRawTextForModel(rawText, options = {}) {
  const maxChars = options.maxChars ?? 5000;
  const maxLines = options.maxLines ?? 80;
  const normalized = normalizeRawText(rawText);
  if (!normalized) return '';

  if (normalized.length <= maxChars) {
    return normalized;
  }

  const lines = normalized
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const scoredLines = lines
    .map((line, index) => ({
      line,
      index,
      score: scoreLine(line),
    }))
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.index - b.index;
    })
    .slice(0, maxLines)
    .sort((a, b) => a.index - b.index)
    .map((entry) => entry.line);

  const compressed = scoredLines.join('\n');
  if (compressed.length <= maxChars) {
    return compressed;
  }

  return compressed.slice(0, maxChars);
}

function parseDateCandidate(value) {
  if (!value) return null;
  const cleaned = String(value).trim().replace(/[,]/g, '');

  const isoMatch = cleaned.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
  }

  const dmyMatch = cleaned.match(/\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b/);
  if (dmyMatch) {
    const year = dmyMatch[3].length === 2 ? `20${dmyMatch[3]}` : dmyMatch[3];
    const month = dmyMatch[2].padStart(2, '0');
    const day = dmyMatch[1].padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  const monthNameMatch = cleaned.match(
    /\b(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b/i,
  );
  if (monthNameMatch) {
    const month = MONTH_MAP[monthNameMatch[2].toLowerCase()];
    const day = monthNameMatch[1].padStart(2, '0');
    return `${monthNameMatch[3]}-${month}-${day}`;
  }

  return null;
}

function detectDocumentTypeHeuristically(text, fileName = '') {
  const haystack = `${fileName}\n${text}`.toLowerCase();

  if (/\b(statement|debit|credit|withdrawal|deposit|available balance|opening balance|closing balance)\b/.test(haystack)) {
    return 'bank_statement';
  }
  if (/\b(agreement|contract|clause|term and condition|termination|obligation)\b/.test(haystack)) {
    return 'contract';
  }
  if (/\b(receipt|cash sale|paid|payment received)\b/.test(haystack)) {
    return 'receipt';
  }
  if (/\b(invoice|tax invoice|bill to|amount due|due date|inv[-\s]?\d+)\b/.test(haystack)) {
    return 'invoice';
  }

  return 'unknown';
}

function detectCompanyNameHeuristically(text) {
  const lines = normalizeRawText(text)
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  for (const line of lines.slice(0, 12)) {
    if (
      line.length >= 4 &&
      line.length <= 80 &&
      /[A-Za-z]/.test(line) &&
      !/invoice|receipt|statement|tax|date|amount|total|page/i.test(line)
    ) {
      return line;
    }
  }

  return null;
}

function detectStatementMonthHeuristically(text) {
  const normalized = normalizeRawText(text);
  const explicit = normalized.match(
    /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b/i,
  );

  if (!explicit) return null;
  const month = MONTH_MAP[explicit[1].toLowerCase()];
  return `${explicit[2]}-${month}`;
}

function extractPrimaryAmount(text) {
  const lines = normalizeRawText(text)
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const prioritized = [];
  const fallback = [];

  for (const line of lines) {
    const matches = [...line.matchAll(/(?:rm|myr)\s*([0-9][0-9,]*\.?[0-9]{0,2})/gi)];
    for (const match of matches) {
      const rawAmount = match[1].replace(/,/g, '');
      const amount = Number(rawAmount);
      if (!Number.isFinite(amount)) continue;

      if (/\b(total|amount due|grand total|balance due|net total)\b/i.test(line)) {
        prioritized.push({ amount, rawLine: line });
      } else {
        fallback.push({ amount, rawLine: line });
      }
    }
  }

  return prioritized[0] || fallback[0] || null;
}

function buildHeuristicFallbackResult(input, reason) {
  const normalizedText = compressRawTextForModel(input.rawText, {
    maxChars: 3500,
    maxLines: 60,
  });
  const providerHints = input.providerHints || {};
  const documentType =
    providerHints.documentType ||
    detectDocumentTypeHeuristically(normalizedText, input.fileName);
  const companyName =
    providerHints.companyName || detectCompanyNameHeuristically(normalizedText);
  const statementMonth =
    documentType === 'bank_statement'
      ? detectStatementMonthHeuristically(normalizedText)
      : null;
  const providerHintDate = parseDateCandidate(providerHints.invoiceDate);
  const invoiceDate = providerHintDate || parseDateCandidate(normalizedText);
  const primaryAmount = extractPrimaryAmount(normalizedText);

  const financialRecords = [];
  if (primaryAmount && (documentType === 'invoice' || documentType === 'receipt')) {
    financialRecords.push({
      recordType: documentType === 'invoice' ? 'invoice_payable' : 'expense',
      transactionDate: invoiceDate,
      dueDate: null,
      description: documentType === 'invoice' ? 'Invoice total' : 'Receipt total',
      category: null,
      amount: primaryAmount.amount,
      currency: 'MYR',
      direction: 'outflow',
      counterpartyName: companyName,
      paymentMethod: null,
      referenceNumber: null,
      confidenceScore: 0.35,
      rawExtractedText: primaryAmount.rawLine,
    });
  }

  return validateExtractionResult({
    documentType,
    classificationConfidence: 0.35,
    companyName,
    invoiceDate,
    statementMonth,
    currency: providerHints.currency || 'MYR',
    normalizedText,
    financialRecords,
    usedFallback: true,
    fallbackReason: reason,
  });
}

async function runExtractionRequest(input, options = {}) {
  const preparedInput = {
    ...input,
    rawText: compressRawTextForModel(input.rawText, {
      maxChars: options.maxChars ?? 5000,
      maxLines: options.maxLines ?? 80,
    }),
  };

  const userPrompt = buildDocumentExtractionPrompt(preparedInput);
  const payload = {
    model: ZAI_MODEL,
    temperature: 0.1,
    messages: [
      { role: 'system', content: DOCUMENT_EXTRACTION_SYSTEM_PROMPT },
      { role: 'user', content: userPrompt },
    ],
  };

  const response = await client.chat.completions.create(payload);
  const content = response?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('No content returned from GLM extraction');
  }

  let parsed;
  try {
    parsed = JSON.parse(stripCodeFences(content));
  } catch (err) {
    throw new Error(`Failed to parse GLM extraction JSON: ${err.message}`);
  }

  return validateExtractionResult(parsed);
}
function validateExtractionResult(result) {
  if (!result || typeof result !== 'object') {
    throw new Error('Extraction result must be an object');
  }

  if (!VALID_DOCUMENT_TYPES.includes(result.documentType)) {
    throw new Error(`Invalid documentType "${result.documentType}"`);
  }

  const confidence = Number(result.classificationConfidence);
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new Error('classificationConfidence must be a number between 0 and 1');
  }

  if (!Array.isArray(result.financialRecords)) {
    throw new Error('financialRecords must be an array');
  }

  const normalizedRecords = result.financialRecords.map((record, index) => {
    if (!VALID_RECORD_TYPES.includes(record.recordType)) {
      throw new Error(`financialRecords[${index}] has invalid recordType`);
    }
    if (!VALID_DIRECTIONS.includes(record.direction)) {
      throw new Error(`financialRecords[${index}] has invalid direction`);
    }

    const amount = Number(record.amount);
    if (!Number.isFinite(amount)) {
      throw new Error(`financialRecords[${index}] has invalid amount`);
    }

    const confidenceScore =
      record.confidenceScore == null ? null : Number(record.confidenceScore);
    if (
      confidenceScore != null &&
      (!Number.isFinite(confidenceScore) || confidenceScore < 0 || confidenceScore > 1)
    ) {
      throw new Error(`financialRecords[${index}] has invalid confidenceScore`);
    }

    return {
      recordType: record.recordType,
      transactionDate: parseOptionalDate(record.transactionDate, `financialRecords[${index}].transactionDate`),
      dueDate: parseOptionalDate(record.dueDate, `financialRecords[${index}].dueDate`),
      description: record.description ? String(record.description).trim() : null,
      category: record.category ? String(record.category).trim() : null,
      amount,
      currency: normalizeCurrency(record.currency),
      direction: record.direction,
      counterpartyName: record.counterpartyName ? String(record.counterpartyName).trim() : null,
      paymentMethod: record.paymentMethod ? String(record.paymentMethod).trim() : null,
      referenceNumber: record.referenceNumber ? String(record.referenceNumber).trim() : null,
      confidenceScore,
      rawExtractedText: record.rawExtractedText ? String(record.rawExtractedText).trim() : null,
    };
  });

  return {
    documentType: result.documentType,
    classificationConfidence: confidence,
    companyName: result.companyName ? String(result.companyName).trim() : null,
    invoiceDate: parseOptionalDate(result.invoiceDate, 'invoiceDate'),
    statementMonth: result.statementMonth ? String(result.statementMonth).trim() : null,
    currency: normalizeCurrency(result.currency),
    normalizedText: result.normalizedText ? String(result.normalizedText).trim() : '',
    financialRecords: normalizedRecords,
    usedFallback: Boolean(result.usedFallback),
    fallbackReason: result.fallbackReason ? String(result.fallbackReason) : null,
  };
}

function buildMockResult(rawText) {
  return validateExtractionResult({
    documentType: 'unknown',
    classificationConfidence: 0.35,
    companyName: null,
    invoiceDate: null,
    statementMonth: null,
    currency: 'MYR',
    normalizedText: rawText.slice(0, 2000),
    financialRecords: [],
  });
}

async function extractStructuredDocumentData(input) {
  if (!input?.rawText || !String(input.rawText).trim()) {
    throw new Error('rawText is required for structured extraction');
  }

  if (USE_MOCK_AI) {
    return buildMockResult(String(input.rawText));
  }

  try {
    return await withTimeout(
      runExtractionRequest(input, {
        maxChars: 3500,
        maxLines: 55,
      }),
      DOCUMENT_EXTRACTION_ATTEMPT_TIMEOUT_MS,
      'Primary GLM extraction',
    );
  } catch (error) {
    const message = error?.message || 'GLM extraction failed';

    try {
      return await withTimeout(
        runExtractionRequest(input, {
          maxChars: 1800,
          maxLines: 30,
        }),
        DOCUMENT_EXTRACTION_RETRY_TIMEOUT_MS,
        'Retry GLM extraction',
      );
    } catch (retryError) {
      const retryMessage =
        retryError?.message || retryError || 'GLM extraction retry failed';
      return {
        ...buildHeuristicFallbackResult(
          input,
          `Heuristic fallback used after GLM failures: ${message}; ${retryMessage}`,
        ),
        usedFallback: true,
        fallbackReason: `Heuristic fallback used after GLM failures: ${message}; ${retryMessage}`,
      };
    }
  }
}

module.exports = {
  extractStructuredDocumentData,
};
