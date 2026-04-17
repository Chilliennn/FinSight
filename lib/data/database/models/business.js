module.exports = {
  name: 'businesses',
  schema: {
    bsonType: 'object',
    required: ['_id', 'name', 'currency', 'created_at'],
    properties: {
      _id: { bsonType: 'string' },
      name: { bsonType: 'string' },
      industry: { bsonType: 'string' },
      safety_buffer_threshold: { bsonType: ['double', 'int'], description: 'Min RM required' },
      currency: { bsonType: 'string' },
      created_at: { bsonType: 'date' }
    }
  }
};
