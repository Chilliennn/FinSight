/**
 * Risk Alert Schema (MongoDB Atlas)
 *
 * Extended to support all fields the UI displays. Backward compatible
 * with original required fields.
 *
 * Severity enum maps to the UI sections:
 *   critical → "Immediate action needed"
 *   high     → "Action within 7 days"
 *   medium   → "Monitor closely"
 *   low      → "Informational"
 */
module.exports = {
  name: 'risk_alerts',
  schema: {
    bsonType: 'object',
    required: [
      '_id',
      'business_id',
      'type',
      'severity',
      'detected_at',
      'status',
      'title',
      'affected_amount'
    ],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },

      type: {
        bsonType: 'string',
        description:
          'Machine-readable: cash_flow_gap | overdue_invoices | expense_spike | revenue_decline | large_payable'
      },
      category: {
        bsonType: 'string',
        description: 'UI chip label: Cash Flow | Receivables | Expenses | Revenue | Payables'
      },
      severity: {
        enum: ['critical', 'high', 'medium', 'low']
      },

      title: { bsonType: 'string' },
      description: { bsonType: 'string' },
      detailed_explanation: {
        bsonType: 'string',
        description: 'AI-generated long-form reasoning (cached from Z.AI)'
      },

      affected_amount: { bsonType: 'double' },
      currency: { bsonType: 'string' },

      timeframe: { bsonType: 'string' },
      trigger_condition: { bsonType: 'string' },

      supporting_data: {
        bsonType: 'object',
        description: 'Numbers that triggered this risk, used by Z.AI prompt'
      },

      detected_at: { bsonType: 'date' },
      resolved_at: { bsonType: ['date', 'null'] },
      status: {
        enum: ['active', 'acknowledged', 'resolved', 'dismissed']
      }
    }
  }
};