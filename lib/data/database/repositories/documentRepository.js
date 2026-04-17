const { getDb } = require('../db');
const { ObjectId } = require('mongodb');

const COLLECTION = 'documents';

async function create(document) {
  const db = await getDb();
  const doc = { ...document };
  if (!doc._id) doc._id = new ObjectId().toHexString();
  await db.collection(COLLECTION).insertOne(doc);
  return doc;
}

async function getById(id) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ _id: id });
}

async function update(id, updates) {
  const db = await getDb();
  await db.collection(COLLECTION).updateOne({ _id: id }, { $set: updates });
  return db.collection(COLLECTION).findOne({ _id: id });
}

async function remove(id) {
  const db = await getDb();
  return db.collection(COLLECTION).deleteOne({ _id: id });
}

async function list(filter = {}, options = {}) {
  const db = await getDb();
  return db.collection(COLLECTION).find(filter, options).toArray();
}

module.exports = { create, getById, update, remove, list };
