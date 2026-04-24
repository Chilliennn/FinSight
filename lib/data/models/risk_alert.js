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
      'affected_amount'
    ],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },

      type: { bsonType: 'string' },
      severity: { enum: ['critical', 'high', 'medium', 'low'] },
      trigger_condition: { bsonType: 'string' },
      detected_at: { bsonType: 'date' },
      status: { enum: ['active', 'resolved'] },
      affected_amount: { bsonType: ['double', 'int'] },

      title: { bsonType: 'string' },
      description: { bsonType: 'string' },
      category: { bsonType: 'string' },
      timeframe: { bsonType: 'string' },

      detailed_explanation: { bsonType: 'string' },
      supporting_data: { bsonType: 'object' },
      ai_metadata: { bsonType: 'object' }
    }
  }
};