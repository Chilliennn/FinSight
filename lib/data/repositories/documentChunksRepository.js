const { Double, Int32, ObjectId } = require('mongodb');
const { getDb } = require('../database/db');

const COLLECTION = 'document_chunks';

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

function toDoubleArray(values) {
  if (!Array.isArray(values)) {
    return [];
  }

  return values.map((value) => new Double(Number(value)));
}

async function insertMany(chunks) {
  if (!Array.isArray(chunks) || chunks.length === 0) {
    return [];
  }

  const db = await getDb();
  const now = new Date();
  const docs = chunks.map((chunk) => ({
    _id: chunk._id ? toObjectId(chunk._id, '_id') : new ObjectId(),
    businessId: toObjectId(chunk.businessId, 'businessId'),
    documentId: toObjectId(chunk.documentId, 'documentId'),
    pageNumber: toNullableInt32(chunk.pageNumber),
    chunkIndex: toNullableInt32(chunk.chunkIndex),
    chunkType: chunk.chunkType || 'paragraph',
    text: String(chunk.text || '').trim(),
    embedding: toDoubleArray(chunk.embedding),
    tokenCount: toNullableInt32(chunk.tokenCount),
    metadata: {
      documentType: chunk.metadata?.documentType ?? null,
      companyName: chunk.metadata?.companyName ?? null,
      statementMonth: chunk.metadata?.statementMonth ?? null,
      invoiceDate: chunk.metadata?.invoiceDate ?? null,
    },
    createdAt: chunk.createdAt || now,
  }));

  await db.collection(COLLECTION).insertMany(docs);
  return docs;
}

async function replaceByDocument(documentId, chunks) {
  const db = await getDb();
  const normalizedDocumentId = toObjectId(documentId, 'documentId');
  await db.collection(COLLECTION).deleteMany({ documentId: normalizedDocumentId });

  return insertMany(
    chunks.map((chunk) => ({
      ...chunk,
      documentId: normalizedDocumentId,
    })),
  );
}

async function deleteByDocument(documentId) {
  const db = await getDb();
  await db
    .collection(COLLECTION)
    .deleteMany({ documentId: toObjectId(documentId, 'documentId') });
}

async function listFirstChunkTextsByDocumentIds(documentIds) {
  if (!Array.isArray(documentIds) || documentIds.length === 0) {
    return new Map();
  }

  const db = await getDb();
  const normalizedIds = documentIds.map((id) => toObjectId(id, 'documentId'));
  const chunks = await db
    .collection(COLLECTION)
    .find(
      { documentId: { $in: normalizedIds } },
      {
        sort: { documentId: 1, chunkIndex: 1 },
        projection: { documentId: 1, text: 1 },
      },
    )
    .toArray();

  const previewMap = new Map();
  for (const chunk of chunks) {
    const key = String(chunk.documentId);
    if (!previewMap.has(key) && chunk.text) {
      previewMap.set(key, String(chunk.text).trim());
    }
  }

  return previewMap;
}

module.exports = {
  deleteByDocument,
  insertMany,
  listFirstChunkTextsByDocumentIds,
  replaceByDocument,
  toObjectId,
};
