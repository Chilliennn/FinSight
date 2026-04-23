/**
 * documents
 * Stores metadata for each uploaded file (PDF/image) belonging to a business.
 *
 * Purpose:
 * - Acts as the main entry point for the document ingestion pipeline
 * - Tracks document type, source, and extracted high-level metadata (e.g. company, dates)
 * - Maintains processing status across stages (OCR → classification → chunking → embedding)
 *
 * Role in system:
 * - Links all downstream data (document_chunks, financial_records) to a single document
 * - Enables filtering by document type, time period, and company
 * - Provides traceability for debugging and explainability
 *
 * Note:
 * This collection does NOT store full text or embeddings.
 * - Raw/processed text → stored in document_chunks
 * - Structured financial data → stored in financial_records
 */

module.exports = {
  name: 'documents',
  schema: {
    bsonType: 'object',
    required: ['_id','businessId','fileName','mimeType','storageUrl','status','createdAt'],
    properties: {
      _id: { bsonType: 'objectId' },
      businessId: { bsonType: 'objectId', description: 'Reference to businesses collection' },
      fileName: { bsonType: 'string' },
      mimeType: { bsonType: 'string', description: 'application/pdf, image/jpeg, etc.' },
      storageUrl: { bsonType: 'string', description: 'URL to Firebase/S3 storage' },
      storageKey: { bsonType: ['string', 'null'], description: 'Provider object key for direct delete/lookups' },
      contentHash: { bsonType: ['string', 'null'], description: 'SHA-256 digest for duplicate detection' },
      sourceType: { bsonType: 'string', enum: ['upload','email','whatsapp','other'] },
      documentType: { bsonType: 'string', enum: ['invoice','receipt','bank_statement','contract','unknown'], description: 'AI-classified document type' },
      classificationConfidence: { bsonType: ['double','null'] },
      companyName: { bsonType: ['string','null'], description: 'Vendor, bank, or issuer name' },
      invoiceDate: { bsonType: ['date','null'] },
      statementMonth: { bsonType: ['string','null'], description: 'Format: YYYY-MM' },
      currency: { bsonType: 'string' },
      totalPages: { bsonType: ['int','null'] },
      ocrRequired: { bsonType: 'bool' },
      status: { bsonType: 'string', enum: ['uploaded','parsed','classified','chunked','embedded','completed','failed'] },
      parsingNotes: { bsonType: ['string','null'] },
      createdAt: { bsonType: 'date' },
      updatedAt: { bsonType: ['date','null'] }
    }
  }
};

