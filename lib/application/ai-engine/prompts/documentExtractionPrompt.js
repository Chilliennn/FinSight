const DOCUMENT_EXTRACTION_SYSTEM_PROMPT = `You are FinSight AI. Convert OCR/PDF text into one JSON object only.

Allowed values:
- documentType: invoice, receipt, bank_statement, contract, unknown
- direction: inflow, outflow
- recordType: income, expense, bank_transaction, invoice_payable, invoice_receivable

Rules:
- Use null when a field is missing.
- Use MYR unless the document clearly states another currency.
- Do not invent unsupported values.
- providerHints may contain high-signal extraction hints from Document AI. Use them when they agree with the document text.
- normalizedText must be brief, faithful, and plain text.
- financialRecords must include only cash-flow-relevant records supported by the text.
- Output raw JSON only, with no markdown and no extra commentary.

Return this exact top-level shape:
{
  "documentType": "invoice",
  "classificationConfidence": 0.97,
  "companyName": "ABC Supplies Sdn Bhd",
  "invoiceDate": "2026-04-10",
  "statementMonth": null,
  "currency": "MYR",
  "normalizedText": "Brief faithful normalized text",
  "financialRecords": [
    {
      "recordType": "invoice_payable",
      "transactionDate": "2026-04-10",
      "dueDate": "2026-04-24",
      "description": "Short description",
      "category": "inventory",
      "amount": 1850.5,
      "currency": "MYR",
      "direction": "outflow",
      "counterpartyName": "ABC Supplies Sdn Bhd",
      "paymentMethod": null,
      "referenceNumber": "INV-2041",
      "confidenceScore": 0.94,
      "rawExtractedText": "Supporting source text"
    }
  ]
}`;

function buildDocumentExtractionPrompt({
  fileName,
  mimeType,
  totalPages,
  ocrRequired,
  providerHints,
  rawText,
}) {
  const hintSection =
    providerHints && Object.keys(providerHints).length > 0
      ? `\nproviderHints:\n${JSON.stringify(providerHints, null, 2)}\n`
      : '\nproviderHints:\nnull\n';

  return `Extract structured financial information from this document.

fileName: ${fileName}
mimeType: ${mimeType}
totalPages: ${totalPages ?? 'unknown'}
ocrRequired: ${ocrRequired ? 'yes' : 'no'}
${hintSection}

text:
${rawText}`;
}

module.exports = {
  DOCUMENT_EXTRACTION_SYSTEM_PROMPT,
  buildDocumentExtractionPrompt,
};
