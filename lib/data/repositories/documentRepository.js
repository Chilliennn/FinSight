const { Double, Int32, ObjectId } = require('mongodb');

const { getDb } = require('../database/db');

const COLLECTION = 'documents';
const MONTH_MAP = {
  january: '01',
  february: '02',
  march: '03',
  april: '04',
  may: '05',
  june: '06',
  july: '07',
  august: '08',
  september: '09',
  october: '10',
  november: '11',
  december: '12',
};

function toObjectId(value, fieldName = 'id') {
  if (value instanceof ObjectId) return value;
  if (!ObjectId.isValid(value)) {
    throw new Error(`Invalid ${fieldName}`);
  }
  return new ObjectId(value);
}

function toNullableInt32(value, fieldName) {
  if (value == null) {
    return null;
  }

  const normalized = Number(value);
  if (!Number.isInteger(normalized)) {
    throw new Error(`Invalid integer value for ${fieldName}`);
  }

  return new Int32(normalized);
}

function toNullableDouble(value, fieldName) {
  if (value == null) {
    return null;
  }

  const normalized = Number(value);
  if (!Number.isFinite(normalized)) {
    throw new Error(`Invalid numeric value for ${fieldName}`);
  }

  return new Double(normalized);
}

function parseDateCandidate(value) {
  if (!value) return null;
  const cleaned = String(value).trim().replace(/[,]/g, '');

  const isoMatch = cleaned.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
  }

  const dmyMatch = cleaned.match(/\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b/);
  if (dmyMatch) {
    const year = dmyMatch[3].length === 2 ? `20${dmyMatch[3]}` : dmyMatch[3];
    const month = dmyMatch[2].padStart(2, '0');
    const day = dmyMatch[1].padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  const monthNameMatch = cleaned.match(
    /\b(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b/i,
  );
  if (monthNameMatch) {
    const month = MONTH_MAP[monthNameMatch[2].toLowerCase()];
    const day = monthNameMatch[1].padStart(2, '0');
    return `${monthNameMatch[3]}-${month}-${day}`;
  }

  return null;
}

function toNullableDate(value, fieldName) {
  if (value == null || value === '') {
    return null;
  }

  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error(`Invalid date for ${fieldName}`);
    }
    return value;
  }

  const normalizedValue =
    typeof value === 'string' ? parseDateCandidate(value) || value : value;
  const parsed = new Date(normalizedValue);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid date for ${fieldName}`);
  }
  return parsed;
}

function normalizeDocument(doc, { isUpdate = false } = {}) {
  const now = new Date();
  const normalized = {
    ...doc,
    updatedAt: now,
  };

  if (!isUpdate) {
    normalized._id = doc._id ? toObjectId(doc._id, '_id') : new ObjectId();
    normalized.businessId = String(doc.businessId);
    normalized.createdAt = doc.createdAt ? toNullableDate(doc.createdAt, 'createdAt') : now;
  } else {
    if (doc._id != null) normalized._id = toObjectId(doc._id, '_id');
    if (doc.businessId != null) {
      normalized.businessId = String(doc.businessId);
    }
    if (doc.createdAt != null) {
      normalized.createdAt = toNullableDate(doc.createdAt, 'createdAt');
    }
  }

  if (doc.invoiceDate !== undefined) {
    normalized.invoiceDate = toNullableDate(doc.invoiceDate, 'invoiceDate');
  }

  if (doc.totalPages !== undefined) {
    normalized.totalPages = toNullableInt32(doc.totalPages, 'totalPages');
  }

  if (doc.classificationConfidence !== undefined) {
    normalized.classificationConfidence = toNullableDouble(
      doc.classificationConfidence,
      'classificationConfidence',
    );
  }

  return normalized;
}

async function create(document) {
  const db = await getDb();
  const doc = normalizeDocument(document);
  await db.collection(COLLECTION).insertOne(doc);
  return doc;
}

async function getById(id) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ _id: toObjectId(id, '_id') });
}

async function update(id, updates) {
  const db = await getDb();
  const normalizedUpdates = normalizeDocument(updates, { isUpdate: true });
  delete normalizedUpdates._id;
  delete normalizedUpdates.businessId;
  delete normalizedUpdates.createdAt;

  await db
    .collection(COLLECTION)
    .updateOne({ _id: toObjectId(id, '_id') }, { $set: normalizedUpdates });
  return getById(id);
}

async function remove(id) {
  const db = await getDb();
  return db.collection(COLLECTION).deleteOne({ _id: toObjectId(id, '_id') });
}

async function list(filter = {}, options = {}) {
  const db = await getDb();
  return db.collection(COLLECTION).find(filter, options).toArray();
}

async function listByBusinessId(businessId, options = {}) {
  return list({ businessId: String(businessId) }, options);
}

async function findByBusinessIdAndContentHash(businessId, contentHash) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({
    businessId: String(businessId),
    contentHash,
  });
}

async function findByBusinessIdAndStorageUrl(businessId, storageUrl) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({
    businessId: String(businessId),
    storageUrl,
  });
}

module.exports = {
  create,
  findByBusinessIdAndContentHash,
  findByBusinessIdAndStorageUrl,
  getById,
  list,
  listByBusinessId,
  remove,
  toObjectId,
  update,
};
