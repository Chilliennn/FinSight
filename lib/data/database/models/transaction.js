module.exports = {
  name: 'transactions',
  schema: {
    bsonType: 'object',
    required: ['_id', 'business_id', 'amount', 'txn_date'],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      document_id: { bsonType: 'string' },
      amount: { bsonType: ['double', 'int'] },
      type: { bsonType: 'string' },
      category: { bsonType: 'string' },
      txn_date: { bsonType: 'date' },
      vendor_name: { bsonType: 'string' },
      is_recurring: { bsonType: 'bool' }
    }
  }
};
