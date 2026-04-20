/**
 * data/database/repositories/recommendationRepository.js
 *
 * The ONLY place that executes MongoDB queries for the recommendations collection.
 * Sits alongside businessRepository.js, transactionRepository.js etc.
 *
 * ARCHITECTURE RULES:
 *   - Imports getDb from '../db' (data/database/db.js) — matches your project layout
 *   - Imports ObjectId from 'mongodb'
 *   - NEVER imported by application/logic/ or application/ai_engine/
 *   - Only called by application/routes/recommendation.routes.js
 *
 * Field contract (matches data/database/models/recommendation.js exactly):
 *   _id, business_id, risk_id, action_title, action_plan, reasoning,
 *   projected_impact_value, impact_type, category, difficulty, timeframe,
 *   rank, action_steps, related_reference, status, actioned_at,
 *   generated_at, expires_at
 */

const { getDb }    = require('../db');          // ← data/database/db.js
const { ObjectId } = require('mongodb');

const COLLECTION = 'recommendations';

/**
 * Insert a single recommendation document.
 * Auto-generates _id if not provided.
 * @param {Object} rec
 * @returns {Promise<Object>} The inserted document (with _id)
 */
async function create(rec) {
  try {
    const db  = await getDb();
    const doc = { ...rec };
    if (!doc._id) doc._id = new ObjectId().toHexString();
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
    const db = await getDb();
    await db.collection(COLLECTION).updateOne({ _id: id }, { $set: updates });
    return db.collection(COLLECTION).findOne({ _id: id });
  } catch (err) {
    throw new Error(`recommendationRepository.update: ${err.message}`);
  }
}

/**
 * Hard-delete a recommendation by _id.
 * @param {string} id
 * @returns {Promise<Object>} MongoDB deleteOne result
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
 * List recommendations matching an arbitrary filter.
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
 * Fetch all active, non-expired recommendations for a business,
 * sorted by rank ascending (rank 1 = highest priority).
 * @param {string} businessId
 * @returns {Promise<Array>}
 */
async function findByBusinessId(businessId) {
  try {
    return list(
      {
        business_id: businessId,
        status:      'active',
        expires_at:  { $gt: new Date() },
      },
      { sort: { rank: 1 } },
    );
  } catch (err) {
    throw new Error(`recommendationRepository.findByBusinessId: ${err.message}`);
  }
}

/**
 * Soft-expire all current active recs for a business, then bulk-insert new batch.
 * Soft-expiry preserves history for audit — docs are not hard-deleted.
 * @param {string}        businessId
 * @param {Array<Object>} docs - Already-validated recommendation documents
 * @returns {Promise<Array<Object>>} The inserted documents
 */
async function replaceAll(businessId, docs) {
  try {
    const db = await getDb();
    await db.collection(COLLECTION).updateMany(
      { business_id: businessId, status: 'active' },
      { $set: { status: 'expired' } },
    );
    if (docs.length === 0) return [];
    await db.collection(COLLECTION).insertMany(docs);
    return docs;
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