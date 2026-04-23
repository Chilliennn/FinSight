'use strict';

const crypto = require('crypto');

const OpenAI = require('openai');

const ZAI_API_KEY = process.env.ZAI_API_KEY;
const ZAI_BASE_URL = (process.env.ZAI_BASE_URL ?? '').replace(/\/$/, '');
const ZAI_EMBEDDING_MODEL = process.env.ZAI_EMBEDDING_MODEL || '';
const AI_TIMEOUT = Number(process.env.AI_REQUEST_TIMEOUT ?? 60000);
const FALLBACK_EMBEDDING_DIMENSIONS = Number(
  process.env.FALLBACK_EMBEDDING_DIMENSIONS ?? 256,
);

if (!ZAI_API_KEY) throw new Error('[documentEmbedding.engine] ZAI_API_KEY is not set');
if (!ZAI_BASE_URL) throw new Error('[documentEmbedding.engine] ZAI_BASE_URL is not set');

const client = new OpenAI({
  apiKey: ZAI_API_KEY,
  baseURL: ZAI_BASE_URL,
  timeout: AI_TIMEOUT,
});

function normalizeInput(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function buildHashedFallbackEmbedding(text, dimensions = FALLBACK_EMBEDDING_DIMENSIONS) {
  const buckets = new Array(dimensions).fill(0);
  const normalized = normalizeInput(text).toLowerCase();
  const terms = normalized.match(/[a-z0-9]+/g) || [];

  for (const term of terms) {
    const digest = crypto.createHash('sha256').update(term).digest();
    const bucketIndex = digest.readUInt16BE(0) % dimensions;
    const sign = digest[2] % 2 === 0 ? 1 : -1;
    const weight = 1 + (digest[3] / 255);
    buckets[bucketIndex] += sign * weight;
  }

  const magnitude = Math.sqrt(
    buckets.reduce((sum, value) => sum + value * value, 0),
  );

  if (magnitude === 0) {
    return buckets;
  }

  return buckets.map((value) => Number((value / magnitude).toFixed(6)));
}

async function embedTexts(texts) {
  const normalizedTexts = texts
    .map((text) => normalizeInput(text))
    .filter(Boolean);

  if (normalizedTexts.length === 0) {
    return {
      vectors: [],
      provider: 'none',
      model: null,
      available: false,
      warning: null,
    };
  }

  if (!ZAI_EMBEDDING_MODEL) {
    return {
      vectors: normalizedTexts.map((text) => buildHashedFallbackEmbedding(text)),
      provider: 'local_hashed_fallback',
      model: 'local_hashed_fallback',
      available: true,
      warning: 'No dedicated embedding model is configured for ILMU, using hashed fallback vectors.',
    };
  }

  try {
    const response = await client.embeddings.create({
      model: ZAI_EMBEDDING_MODEL,
      input: normalizedTexts,
    });

    const vectors = (response.data || []).map((item) =>
      Array.isArray(item.embedding)
        ? item.embedding.map((value) => Number(value))
        : [],
    );

    if (vectors.length !== normalizedTexts.length || vectors.some((vector) => vector.length === 0)) {
      throw new Error('Embedding response shape was incomplete');
    }

    return {
      vectors,
      provider: 'zai_embeddings',
      model: ZAI_EMBEDDING_MODEL,
      available: true,
      warning: null,
    };
  } catch (error) {
    return {
      vectors: normalizedTexts.map((text) => buildHashedFallbackEmbedding(text)),
      provider: 'local_hashed_fallback',
      model: 'local_hashed_fallback',
      available: true,
      warning: error.message || 'Embedding endpoint unavailable, using hashed fallback vectors.',
    };
  }
}

module.exports = {
  embedTexts,
};
