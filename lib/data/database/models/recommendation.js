module.exports = {
  name: 'recommendations',
  schema: {
    bsonType: 'object',
    required: ['_id', 'risk_id', 'business_id', 'action_title', 'action_plan', 'status'],
    properties: {
      _id: { bsonType: 'string' },
      risk_id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      action_title: { bsonType: 'string' },
      action_plan: { bsonType: 'string' },
      reasoning: { bsonType: 'string' },
      projected_impact_value: { bsonType: ['double', 'int'] },
      impact_type: { bsonType: 'string' },
      status: { bsonType: 'string' }
    }
  }
};
