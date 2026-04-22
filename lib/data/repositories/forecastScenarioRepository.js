const { getDb } = require('../database/db');

const { getDb } = require('../database/db');

const { ObjectId } = require('mongodb');

const COLLECTION = 'forecast_scenarios';

async function create(scenario) {
  const db = await getDb();
  const doc = { ...scenario };
  if (!doc._id) doc._id = new ObjectId().toHexString();
  if (!doc.calculated_at) doc.calculated_at = new Date();
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

