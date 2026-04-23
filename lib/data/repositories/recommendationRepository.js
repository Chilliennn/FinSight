
// data/repositories/recommendationRepository.js

const { getDb }           = require('../database/db');
const { ObjectId, Int32 } = require('mongodb');

// const { getDb }    = require('../database/db');          // ← data/database/db.js
// const { ObjectId } = require('mongodb');

const COLLECTION = 'recommendations';

const newId = () => new ObjectId().toHexString();


function coerceIntFields(doc) {
  return {
    ...doc,
    rank: new Int32(Number(doc.rank)),
    action_steps: (doc.action_steps ?? []).map((s) => ({
      ...s,
      step_number: new Int32(Number(s.step_number)),
    })),
  };
}

/**
 * Insert a single recommendation document.
 * @param {Object} rec - Document without _id (assigned here)
 * @returns {Promise<Object>} The inserted document (with _id)
 */
async function create(rec) {
  try {
    const db  = await getDb();
    const doc = coerceIntFields({ ...rec, _id: rec._id ?? newId() });
    await db.collection(COLLECTION).insertOne(doc);
    return doc;
  } catch (err) {
    throw new Error(`recommendationRepository.create: ${err.message}`);
  }
}

/**
 * Find a single recommendation by its string _id.
 * @param {string} id
 * @returns {Promise<Object|null>}
 */
async function getById(id) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).findOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.getById: ${err.message}`);
  }
}

/**
 * Partial-update a recommendation by _id.
 * @param {string} id
 * @param {Object} updates - Fields to $set
 * @returns {Promise<Object|null>} The updated document
 */
async function update(id, updates) {
  try {
    const db     = await getDb();
    const result = await db.collection(COLLECTION).findOneAndUpdate(
      { _id: id },
      { $set: updates },
      { returnDocument: 'after' },
    );
    return result ?? null;
  } catch (err) {
    throw new Error(`recommendationRepository.update: ${err.message}`);
  }
}

/**
 * @param {string} id
 * @returns {Promise<Object>} MongoDB deleteOne result ({ deletedCount })
 */
async function remove(id) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).deleteOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.remove: ${err.message}`);
  }
}

/**
 * @param {Object} filter  - MongoDB filter document
 * @param {Object} options - MongoDB find options (sort, projection, etc.)
 * @returns {Promise<Array>}
 */
async function list(filter = {}, options = {}) {
  try {
    const db = await getDb();
    return db.collection(COLLECTION).find(filter, options).toArray();
  } catch (err) {
    throw new Error(`recommendationRepository.list: ${err.message}`);
  }
}

/**
 
 * @param {string} businessId
 * @returns {Promise<Array>}
 */
async function findByBusinessId(businessId) {
  try {
    const now = new Date();
    return list(
      {
        business_id: businessId,
        status:      'active',
        expires_at:  { $gt: now },
      },
      { sort: { rank: 1 } },
    );
  } catch (err) {
    throw new Error(`recommendationRepository.findByBusinessId: ${err.message}`);
  }
}

/**
 * Soft-expire all active recs for a business, then insert a new batch.
 * @param {string}        businessId
 * @param {Array<Object>} docs - Already-validated recommendation documents (no _id yet)
 * @returns {Promise<Array<Object>>} The inserted documents (each with _id)
 */
async function replaceAll(businessId, docs) {
  try {
    const db = await getDb();

    await db.collection(COLLECTION).updateMany(
      { business_id: businessId, status: 'active' },
      { $set: { status: 'expired' } },
    );

    if (docs.length === 0) return [];

    const docsWithIds = docs.map((doc) =>
      coerceIntFields({ ...doc, _id: newId() }),
    );

    await db.collection(COLLECTION).insertMany(docsWithIds, { ordered: false });

    return docsWithIds;
  } catch (err) {
    throw new Error(`recommendationRepository.replaceAll: ${err.message}`);
  }
}

/**
 * Mark a recommendation as actioned (status: 'active' → 'actioned').
 * @param {string} id
 * @returns {Promise<Object|null>} Updated document
 */
async function markActioned(id) {
  try {
    return update(id, {
      status:      'actioned',
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