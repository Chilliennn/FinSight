/**
 * financial_records
 * Stores structured financial data (amounts, dates, inflow/outflow) extracted from documents.
 *
 * Purpose:
 * - Enables accurate financial calculations (cash flow, totals, trends)
 * - Used directly by the decision engine to detect risks (e.g. cash flow gaps)
 * - Eliminates the need to re-parse raw documents for numeric analysis
 *
 * Note:
 * This collection contains only structured facts. It does NOT store full text,
 * contract terms, or contextual explanations — those are handled by document_chunks.
 */

module.exports = {
  name: 'financial_records',
  schema: {
    bsonType: 'object',
    required: ['_id','businessId','documentId','recordType','amount','currency','direction','createdAt'],
    properties: {
      _id: { bsonType: 'objectId' },
      businessId: { bsonType: 'string' },
      documentId: { bsonType: 'objectId' },

      pageNumber: { bsonType: ['int','null'] },

      recordType: { bsonType: 'string', enum: ['income','expense','bank_transaction','invoice_payable','invoice_receivable'] },

      transactionDate: { bsonType: ['date','null'] },
      dueDate: { bsonType: ['date','null'] },

      description: { bsonType: ['string','null'] },
      category: { bsonType: ['string','null'] },

      amount: { bsonType: 'double' },
      currency: { bsonType: 'string' },

      direction: { bsonType: 'string', enum: ['inflow','outflow'] },

      counterpartyName: { bsonType: ['string','null'] },

      paymentMethod: { bsonType: ['string','null'] },
      referenceNumber: { bsonType: ['string','null'] },

      sourceDocumentType: { bsonType: ['string','null'], enum: ['invoice','receipt','bank_statement','contract','unknown'] },

      confidenceScore: { bsonType: ['double','null'] },

      rawExtractedText: { bsonType: ['string','null'] },

      createdAt: { bsonType: 'date' },
      updatedAt: { bsonType: ['date','null'] }
    }
  }
};
