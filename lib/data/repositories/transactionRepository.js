'use strict';

const { Double, ObjectId } = require('mongodb');

const { getDb } = require('../database/db');

const COLLECTION = 'transactions';

function toTransactionId(value) {
  return value ? String(value) : new ObjectId().toHexString();
}

function toDocumentIdString(value, fieldName = 'document_id') {
  if (value == null || value === '') {
    return null;
  }

  if (value instanceof ObjectId) {
    return value.toHexString();
  }

  if (!ObjectId.isValid(value)) {
    throw new Error(`Invalid ${fieldName}`);
  }

  return new ObjectId(value).toHexString();
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

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid date for ${fieldName}`);
  }

  return parsed;
}

function toAmount(value) {
  const normalized = Number(value);
  if (!Number.isFinite(normalized)) {
    throw new Error(`Invalid amount "${value}"`);
  }

  return new Double(normalized);
}

function assignIfPresent(target, key, value) {
  if (value !== undefined && value !== null && value !== '') {
    target[key] = value;
  }
}

function normalizeTransaction(record) {
  const txnDate = toNullableDate(record.txn_date, 'txn_date');
  if (!txnDate) {
    throw new Error('txn_date is required');
  }

  const normalized = {
    _id: toTransactionId(record._id),
    business_id: String(record.business_id),
    amount: toAmount(record.amount),
    type: String(record.type),
    category: String(record.category),
    txn_date: txnDate,
    vendor_name: String(record.vendor_name),
    is_recurring: Boolean(record.is_recurring),
    is_paid: Boolean(record.is_paid),
  };

  assignIfPresent(
    normalized,
    'document_id',
    toDocumentIdString(record.document_id, 'document_id'),
  );
  assignIfPresent(
    normalized,
    'due_date',
    toNullableDate(record.due_date, 'due_date'),
  );

  return normalized;
}

async function create(transaction) {
  const db = await getDb();
  const doc = normalizeTransaction(transaction);
  await db.collection(COLLECTION).insertOne(doc);
  return doc;
}

async function insertMany(transactions) {
  if (!Array.isArray(transactions) || transactions.length === 0) {
    return [];
  }

  const db = await getDb();
  const docs = transactions.map(normalizeTransaction);
  await db.collection(COLLECTION).insertMany(docs);
  return docs;
}

async function getById(id) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ _id: String(id) });
}

async function update(id, updates) {
  const db = await getDb();
  const normalized = { ...updates };
  delete normalized._id;
  delete normalized.business_id;

  if (updates.document_id !== undefined) {
    normalized.document_id = toDocumentIdString(updates.document_id, 'document_id');
  }
  if (updates.amount !== undefined) {
    normalized.amount = toAmount(updates.amount);
  }
  if (updates.txn_date !== undefined) {
    normalized.txn_date = toNullableDate(updates.txn_date, 'txn_date');
  }
  if (updates.due_date !== undefined) {
    const dueDate = toNullableDate(updates.due_date, 'due_date');
    if (dueDate == null) {
      delete normalized.due_date;
    } else {
      normalized.due_date = dueDate;
    }
  }

  await db.collection(COLLECTION).updateOne({ _id: String(id) }, { $set: normalized });
  return db.collection(COLLECTION).findOne({ _id: String(id) });
}

async function remove(id) {
  const db = await getDb();
  return db.collection(COLLECTION).deleteOne({ _id: String(id) });
}

async function list(filter = {}, options = {}) {
  const db = await getDb();
  return db.collection(COLLECTION).find(filter, options).toArray();
}

async function deleteByDocument(documentId) {
  const db = await getDb();
  const normalizedDocumentId = toDocumentIdString(documentId, 'document_id');
  await db.collection(COLLECTION).deleteMany({ document_id: normalizedDocumentId });
}

async function replaceByDocument(documentId, transactions) {
  const normalizedDocumentId = toDocumentIdString(documentId, 'document_id');
  const db = await getDb();
  await db.collection(COLLECTION).deleteMany({ document_id: normalizedDocumentId });

  return insertMany(
    transactions.map((transaction) => ({
      ...transaction,
      document_id: normalizedDocumentId,
    })),
  );
}

module.exports = {
  create,
  deleteByDocument,
  getById,
  insertMany,
  list,
  remove,
  replaceByDocument,
  update,
};
