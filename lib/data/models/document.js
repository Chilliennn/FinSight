module.exports = {
  name: 'documents',
  schema: {
    bsonType: 'object',
    required: ['_id', 'business_id', 'file_type', 'storage_url', 'status'],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      file_type: { bsonType: 'string' },
      storage_url: { bsonType: 'string' },
      raw_content: { bsonType: 'string' },
      vector_id: { bsonType: 'string' },
      status: { bsonType: 'string' }
    }
  }
};

