module.exports = {
  name: 'forecast_scenarios',
  schema: {
    bsonType: 'object',
    required: ['_id', 'business_id', 'scenario_name', 'calculated_at'],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      scenario_name: { bsonType: 'string' },
      assumptions: { bsonType: 'object' },
      predicted_balance_6w: { bsonType: ['double', 'int'] },
      calculated_at: { bsonType: 'date' }
    }
  }
};
