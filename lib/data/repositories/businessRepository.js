const { getDb } = require('../databa../../database/db');
const { ObjectId } = require('mongodb');

const COLLECTION = 'businesses';

async function create(business) {
  const db = await getDb();
  const doc = { ...business };
  if (!doc._id) doc._id = new ObjectId().toHexString();
  if (!doc.created_at) doc.created_at = new Date();
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

