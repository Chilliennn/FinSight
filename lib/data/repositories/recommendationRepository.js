/**
 * data/database/repositories/recommendationRepository.js
 */

const { getDb }    = require('../db');
const { ObjectId, Int32 } = require('mongodb');

const COLLECTION = 'recommendations';

/** Generate a fresh hex string _id. */
const newId = () => new ObjectId().toHexString();

/**
 *
 * @param {Object} doc
 * @returns {Object}
 */
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
    // MongoDB driver v5+: findOneAndUpdate returns the document directly (not a result wrapper)
    return result ?? null;
  } catch (err) {
    throw new Error(`recommendationRepository.update: ${err.message}`);
  }
}

/**
 * Hard-delete a recommendation by _id.
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
 * @param {string}        businessId
 * @param {Array<Object>} docs - Already-validated recommendation documents (no _id yet)
 * @returns {Promise<Array<Object>>} The inserted documents (each with _id)
 */
async function replaceAll(businessId, docs) {
  try {
    const db = await getDb();

    // Soft-expire old active recs for this business
    await db.collection(COLLECTION).updateMany(
      { business_id: businessId, status: 'active' },
      { $set: { status: 'expired' } },
    );

    if (docs.length === 0) return [];

    // Assign _id and coerce int fields before insert
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