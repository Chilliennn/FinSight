module.exports = {
  name: 'risk_alerts',
  schema: {
    bsonType: 'object',
    required: ['_id', 'business_id', 'type', 'severity', 'detected_at', 'status'],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      type: { bsonType: 'string' },
      severity: { bsonType: 'string' },
      trigger_condition: { bsonType: 'string' },
      detected_at: { bsonType: 'date' },
      status: { bsonType: 'string' }
    }
  }
};
