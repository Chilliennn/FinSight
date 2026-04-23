const { ObjectId } = require('mongodb');
const { getDb } = require('../database/db');

const COLLECTION = 'documents';

function toObjectId(value, fieldName = 'id') {
  if (value instanceof ObjectId) return value;
  if (!ObjectId.isValid(value)) {
    throw new Error(`Invalid ${fieldName}`);
  }
  return new ObjectId(value);
}

async function create(document) {
  const db = await getDb();
  const now = new Date();

  const doc = {
    _id: document._id ? toObjectId(document._id, '_id') : new ObjectId(),
    businessId: toObjectId(document.businessId, 'businessId'),
    fileName: document.fileName,
    mimeType: document.mimeType,
    storageUrl: document.storageUrl,
    storageKey: document.storageKey ?? null,
    contentHash: document.contentHash ?? null,
    sourceType: document.sourceType || 'upload',
    documentType: document.documentType || 'unknown',
    classificationConfidence: document.classificationConfidence ?? null,
    companyName: document.companyName ?? null,
    invoiceDate: document.invoiceDate ?? null,
    statementMonth: document.statementMonth ?? null,
    currency: document.currency || 'MYR',
    totalPages: document.totalPages ?? null,
    ocrRequired: document.ocrRequired ?? false,
    status: document.status || 'uploaded',
    parsingNotes: document.parsingNotes ?? null,
    createdAt: document.createdAt || now,
    updatedAt: document.updatedAt ?? null,
  };

  await db.collection(COLLECTION).insertOne(doc);
  return doc;
}

async function getById(id) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ _id: toObjectId(id) });
}

async function update(id, updates) {
  const db = await getDb();
  const normalized = { ...updates, updatedAt: new Date() };
  if (normalized.businessId) {
    normalized.businessId = toObjectId(normalized.businessId, 'businessId');
  }
  if (normalized._id) {
    delete normalized._id;
  }

  await db
    .collection(COLLECTION)
    .updateOne({ _id: toObjectId(id) }, { $set: normalized });

  return getById(id);
}

async function remove(id) {
  const db = await getDb();
  return db.collection(COLLECTION).deleteOne({ _id: toObjectId(id) });
}

async function list(filter = {}, options = {}) {
  const db = await getDb();
  return db.collection(COLLECTION).find(filter, options).toArray();
}

async function listByBusinessId(businessId, options = {}) {
  return list({ businessId: toObjectId(businessId, 'businessId') }, options);
}

async function findByBusinessIdAndContentHash(businessId, contentHash) {
  if (!contentHash) return null;
  const db = await getDb();
  return db.collection(COLLECTION).findOne({
    businessId: toObjectId(businessId, 'businessId'),
    contentHash,
  });
}

async function findByBusinessIdAndStorageUrl(businessId, storageUrl) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({
    businessId: toObjectId(businessId, 'businessId'),
    storageUrl,
  });
}

async function ensureIndexes() {
  const db = await getDb();
  await db.collection(COLLECTION).createIndex(
    { businessId: 1, contentHash: 1 },
    {
      unique: true,
      partialFilterExpression: {
        contentHash: { $exists: true, $type: 'string' },
      },
      name: 'business_content_hash_unique',
    },
  );
}

module.exports = {
  create,
  ensureIndexes,
  findByBusinessIdAndContentHash,
  findByBusinessIdAndStorageUrl,
  getById,
  update,
  remove,
  list,
  listByBusinessId,
  toObjectId,
};
