const crypto = require('crypto');
const path = require('path');
const {
  DeleteObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} = require('@aws-sdk/client-s3');

const endpoint = process.env.R2_S3_ENDPOINT;
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
const bucket = process.env.R2_BUCKET;

function assertConfig() {
  const missing = [
    ['R2_S3_ENDPOINT', endpoint],
    ['R2_ACCESS_KEY_ID', accessKeyId],
    ['R2_SECRET_ACCESS_KEY', secretAccessKey],
    ['R2_BUCKET', bucket],
  ]
    .filter(([, value]) => !value)
    .map(([key]) => key);

  if (missing.length > 0) {
    throw new Error(`Missing R2 configuration: ${missing.join(', ')}`);
  }
}

function createClient() {
  assertConfig();

  return new S3Client({
    region: 'auto',
    endpoint,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
    forcePathStyle: true,
  });
}

function sanitizeFileName(fileName) {
  const extension = path.extname(fileName || '').toLowerCase();
  const baseName = path.basename(fileName || 'upload', extension);
  const cleanedBase = baseName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);

  return `${cleanedBase || 'document'}${extension}`;
}

function buildObjectKey({ businessId, fileName }) {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const stamp = now.toISOString().replace(/[:.]/g, '-');
  const randomSuffix = crypto.randomBytes(6).toString('hex');

  return `documents/${businessId}/${year}/${month}/${stamp}-${randomSuffix}-${sanitizeFileName(fileName)}`;
}

function buildStorageUrl(key) {
  const normalizedEndpoint = endpoint.replace(/\/$/, '');
  const encodedKey = key
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');

  return `${normalizedEndpoint}/${bucket}/${encodedKey}`;
}

function getDocumentPrefix(businessId) {
  return `documents/${businessId}/`;
}

function parseObjectKeyFromStorageUrl(storageUrl) {
  if (!storageUrl) return null;

  const normalizedEndpoint = endpoint.replace(/\/$/, '');
  const prefix = `${normalizedEndpoint}/${bucket}/`;

  if (!storageUrl.startsWith(prefix)) {
    return null;
  }

  const encodedKey = storageUrl.slice(prefix.length);
  return decodeURIComponent(encodedKey);
}

async function uploadDocument({ businessId, fileName, mimeType, buffer }) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('Cannot upload empty file');
  }

  const client = createClient();
  const key = buildObjectKey({ businessId, fileName });

  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: buffer,
      ContentType: mimeType,
    }),
  );

  return {
    bucket,
    key,
    storageUrl: buildStorageUrl(key),
  };
}

async function listDocumentsForBusiness(businessId) {
  const client = createClient();
  const prefix = getDocumentPrefix(businessId);
  const items = [];
  let continuationToken;

  do {
    const response = await client.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: prefix,
        ContinuationToken: continuationToken,
      }),
    );

    const contents = response.Contents || [];
    for (const item of contents) {
      if (!item.Key) continue;
      items.push({
        key: item.Key,
        storageUrl: buildStorageUrl(item.Key),
        size: item.Size || 0,
        lastModified: item.LastModified || null,
      });
    }

    continuationToken = response.IsTruncated
      ? response.NextContinuationToken
      : undefined;
  } while (continuationToken);

  return items.sort((a, b) => {
    const aTime = a.lastModified ? new Date(a.lastModified).getTime() : 0;
    const bTime = b.lastModified ? new Date(b.lastModified).getTime() : 0;
    return bTime - aTime;
  });
}

async function getDocumentBuffer(key) {
  const client = createClient();
  const response = await client.send(
    new GetObjectCommand({
      Bucket: bucket,
      Key: key,
    }),
  );

  if (!response.Body) {
    throw new Error('R2 object body is empty');
  }

  const bytes = await response.Body.transformToByteArray();
  return Buffer.from(bytes);
}

async function deleteDocument(key) {
  if (!key) {
    throw new Error('R2 object key is required for delete');
  }

  const client = createClient();
  await client.send(
    new DeleteObjectCommand({
      Bucket: bucket,
      Key: key,
    }),
  );
}

module.exports = {
  buildStorageUrl,
  deleteDocument,
  getDocumentBuffer,
  getDocumentPrefix,
  listDocumentsForBusiness,
  parseObjectKeyFromStorageUrl,
  uploadDocument,
};
