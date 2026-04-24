/**
 * data/database/repositories/recommendationRepository.js
 */

const { getDb } = require('../database/db');
const { ObjectId } = require('mongodb');

const COLLECTION = 'recommendations';

async function create(recommendation) {
  try {
    const db = await getDb();
    const doc = { ...recommendation };
    if (!doc._id) doc._id = new ObjectId().toHexString();
    await db.collection(COLLECTION).insertOne(doc);
    return doc;
  } catch (err) {
    throw new Error(`recommendationRepository.create: ${err.message}`);
  }
}

async function getById(id) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).findOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.getById: ${err.message}`);
  }
}

async function update(id, updates) {
  try {
    const db = await getDb();
    await db.collection(COLLECTION).updateOne({ _id: id }, { $set: updates });
    return db.collection(COLLECTION).findOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.update: ${err.message}`);
  }
}

async function remove(id) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).deleteOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.remove: ${err.message}`);
  }
}

async function list(filter = {}, options = {}) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).find(filter, options).toArray();
  } catch (err) {
    throw new Error(`recommendationRepository.list: ${err.message}`);
  }
}

async function findByBusinessId(businessId) {
  try {
    return list(
      {
        business_id: businessId,
        status: 'active',
        expires_at: { $gt: new Date() },
      },
      { sort: { rank: 1 } },
    );
  } catch (err) {
    throw new Error(
      `recommendationRepository.findByBusinessId: ${err.message}`,
    );
  }
}

async function replaceAll(businessId, docs) {
  try {
    const db = await getDb();
    await db.collection(COLLECTION).updateMany(
      { business_id: businessId, status: 'active' },
      { $set: { status: 'expired' } },
    );
    if (docs.length === 0) {
      return [];
    }
    await db.collection(COLLECTION).insertMany(docs);
    return docs;
  } catch (err) {
    throw new Error(`recommendationRepository.replaceAll: ${err.message}`);
  }
}

async function markActioned(id) {
  try {
    return update(id, {
      status: 'actioned',
      actioned_at: new Date(),
    });
  } catch (err) {
    throw new Error(`recommendationRepository.markActioned: ${err.message}`);
  }
}

module.exports = {
  create,
  getById,
  update,
  remove,
  list,
  findByBusinessId,
  replaceAll,
  markActioned,
};
