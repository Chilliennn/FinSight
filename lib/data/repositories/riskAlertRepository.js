/**
 * Risk Alert Repository — "The Librarian"
 *
 * Per Manifesto §5: only place allowed to query MongoDB for risk_alerts.
 */
const { getDb } = require('../database/db');
const { ObjectId } = require('mongodb');

const COLLECTION = 'risk_alerts';

async function create(alert) {
  const db = await getDb();
  const doc = {
    status: 'active',
    detected_at: new Date(),
    ...alert
  };
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

/**
 * List active risks sorted by severity (critical first), then by
 * affected_amount desc — matches UI rendering order.
 */
async function listActiveByBusiness(businessId) {
  const db = await getDb();
  const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 };

  const docs = await db
    .collection(COLLECTION)
    .find({ business_id: businessId, status: 'active' })
    .toArray();

  return docs.sort((a, b) => {
    const s = severityOrder[a.severity] - severityOrder[b.severity];
    if (s !== 0) return s;
    return (b.affected_amount || 0) - (a.affected_amount || 0);
  });
}

/**
 * Returns { critical, high, medium, low } counts for the 4 summary cards.
 */
async function getSeverityCounts(businessId) {
  const db = await getDb();
  const pipeline = [
    { $match: { business_id: businessId, status: 'active' } },
    { $group: { _id: '$severity', count: { $sum: 1 } } }
  ];
  const rows = await db.collection(COLLECTION).aggregate(pipeline).toArray();
  const counts = { critical: 0, high: 0, medium: 0, low: 0 };
  rows.forEach((r) => {
    if (counts[r._id] !== undefined) counts[r._id] = r.count;
  });
  return counts;
}

/**
 * Upsert by (business_id, type) — prevents duplicate alerts when
 * the detector re-runs. Preserves original detected_at.
 */
async function upsertByTypeAndBusiness(businessId, type, alertData) {
  const db = await getDb();
  const filter = { business_id: businessId, type, status: 'active' };

  const existing = await db.collection(COLLECTION).findOne(filter);
  if (existing) {
    await db.collection(COLLECTION).updateOne(
      { _id: existing._id },
      {
        $set: {
          ...alertData,
          business_id: businessId,
          type,
          detected_at: existing.detected_at,
          _id: existing._id
        }
      }
    );
    return db.collection(COLLECTION).findOne({ _id: existing._id });
  }

  return create({ ...alertData, business_id: businessId, type });
}

module.exports = {
  create,
  getById,
  update,
  remove,
  list,
  listActiveByBusiness,
  getSeverityCounts,
  upsertByTypeAndBusiness
};

