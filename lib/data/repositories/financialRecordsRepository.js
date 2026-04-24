const { Double, Int32, ObjectId } = require('mongodb');
const { getDb } = require('../database/db');

const COLLECTION = 'financial_records';

function toObjectId(value, fieldName = 'id') {
  if (value instanceof ObjectId) return value;
  if (!ObjectId.isValid(value)) {
    throw new Error(`Invalid ${fieldName}`);
  }
  return new ObjectId(value);
}

function toNullableInt32(value) {
  if (value == null) {
    return null;
  }

  const normalized = Number(value);
  if (!Number.isInteger(normalized)) {
    throw new Error(`Expected integer-compatible value, received "${value}"`);
  }

  return new Int32(normalized);
}

function toDouble(value, fieldName) {
  const normalized = Number(value);
  if (!Number.isFinite(normalized)) {
    throw new Error(`Invalid numeric value for ${fieldName}`);
  }

  return new Double(normalized);
}

function toNullableDouble(value) {
  if (value == null) {
    return null;
  }

  return toDouble(value, 'confidenceScore');
}

async function insertMany(records) {
  if (!Array.isArray(records) || records.length === 0) {
    return [];
  }

  const db = await getDb();
  const now = new Date();
  const docs = records.map((record) => ({
    _id: record._id ? toObjectId(record._id, '_id') : new ObjectId(),
    businessId: String(record.businessId),
    documentId: toObjectId(record.documentId, 'documentId'),
    pageNumber: toNullableInt32(record.pageNumber),
    recordType: record.recordType,
    transactionDate: record.transactionDate ?? null,
    dueDate: record.dueDate ?? null,
    description: record.description ?? null,
    category: record.category ?? null,
    amount: toDouble(record.amount, 'amount'),
    currency: record.currency,
    direction: record.direction,
    counterpartyName: record.counterpartyName ?? null,
    paymentMethod: record.paymentMethod ?? null,
    referenceNumber: record.referenceNumber ?? null,
    sourceDocumentType: record.sourceDocumentType ?? null,
    confidenceScore: toNullableDouble(record.confidenceScore),
    rawExtractedText: record.rawExtractedText ?? null,
    createdAt: record.createdAt || now,
    updatedAt: record.updatedAt ?? null,
  }));

  await db.collection(COLLECTION).insertMany(docs);
  return docs;
}

async function replaceByDocument(documentId, records) {
  const db = await getDb();
  const normalizedDocumentId = toObjectId(documentId, 'documentId');
  await db.collection(COLLECTION).deleteMany({ documentId: normalizedDocumentId });
  return insertMany(
    records.map((record) => ({
      ...record,
      documentId: normalizedDocumentId,
    })),
  );
}

async function listByDocument(documentId, options = {}) {
  const db = await getDb();
  return db
    .collection(COLLECTION)
    .find({ documentId: toObjectId(documentId, 'documentId') }, options)
    .toArray();
}

async function deleteByDocument(documentId) {
  const db = await getDb();
  const normalizedDocumentId = toObjectId(documentId, 'documentId');
  await db.collection(COLLECTION).deleteMany({ documentId: normalizedDocumentId });
}

module.exports = {
  deleteByDocument,
  insertMany,
  listByDocument,
  replaceByDocument,
  toObjectId,
};
