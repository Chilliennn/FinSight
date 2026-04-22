/**
 * document_chunks
 * Stores text chunks extracted from documents along with embeddings for semantic search (RAG).
 *
 * Purpose:
 * - Provides unstructured context (contracts, notes, explanations, clauses)
 * - Enables AI to explain "why" a financial decision or risk exists
 * - Supports retrieval of relevant document evidence during LLM prompting
 *
 * Why this exists (IMPORTANT):
 * financial_records only store structured data (numbers, dates, categories).
 * However, many important details such as payment terms, penalties, and conditions
 * exist only in raw text (e.g. contracts, invoice notes).
 *
 * This collection allows the system to:
 * - retrieve supporting evidence (e.g. "payment due in 14 days")
 * - reduce hallucination by grounding responses in real document content
 * - generate explainable, trustworthy financial insights
 */

module.exports = {
  name: 'document_chunks',
  schema: {
    bsonType: 'object',
    required: ['_id','businessId','documentId','chunkIndex','text','embedding','createdAt'],
    properties: {
      _id: { bsonType: 'objectId' },
      businessId: { bsonType: 'objectId' },
      documentId: { bsonType: 'objectId' },

      pageNumber: { bsonType: ['int','null'] },

      chunkIndex: { bsonType: 'int' },

      chunkType: { bsonType: 'string', enum: ['paragraph','table','header','section'] },

      text: { bsonType: 'string' },

      embedding: { bsonType: 'array', items: { bsonType: 'double' } },

      tokenCount: { bsonType: ['int','null'] },

      metadata: {
        bsonType: 'object',
        properties: {
          documentType: { bsonType: ['string','null'] },
          companyName: { bsonType: ['string','null'] },
          statementMonth: { bsonType: ['string','null'] },
          invoiceDate: { bsonType: ['date','null'] }
        }
      },

      createdAt: { bsonType: 'date' }
    }
  }
};