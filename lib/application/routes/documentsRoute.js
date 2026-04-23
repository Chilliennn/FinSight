const express = require('express');
const multer = require('multer');
const { ObjectId } = require('mongodb');
const crypto = require('crypto');

const { extractStructuredDocumentData } = require('../ai-engine/documentExtraction.engine');
const { embedTexts } = require('../ai-engine/documentEmbedding.engine');
const { chunkDocumentText } = require('../logic/documentChunking');
const { extractDocumentText } = require('../logic/documentTextExtraction');
const documentRepository = require('../../data/repositories/documentRepository');
const documentChunksRepository = require('../../data/repositories/documentChunksRepository');
const financialRecordsRepository = require('../../data/repositories/financialRecordsRepository');
const {
  buildStorageUrl,
  deleteDocument,
  listDocumentsForBusiness,
  parseObjectKeyFromStorageUrl,
  uploadDocument,
} = require('../../data/storage/r2Storage');

const router = express.Router();
const EXTRACTION_TIMEOUT_MS = Number(process.env.EXTRACTION_TIMEOUT_MS ?? 45000);
const CLASSIFICATION_TIMEOUT_MS = Number(process.env.CLASSIFICATION_TIMEOUT_MS ?? 120000);
const EMBEDDING_TIMEOUT_MS = Number(process.env.EMBEDDING_TIMEOUT_MS ?? 20000);

const ACCEPTED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024,
  },
  fileFilter: (req, file, cb) => {
    if (!ACCEPTED_MIME_TYPES.has(file.mimetype)) {
      cb(new Error('Only PDF, JPG, and PNG files are supported'));
      return;
    }
    cb(null, true);
  },
});

function ok(data) {
  return { success: true, data, error: null };
}

function fail(error, data = null) {
  return { success: false, data, error };
}

function computeContentHash(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function parseNotes(notes) {
  if (!notes) return {};
  if (typeof notes === 'object' && !Array.isArray(notes)) return notes;
  if (typeof notes !== 'string') return {};

  try {
    const parsed = JSON.parse(notes);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch {
    return { message: notes };
  }
}

function stringifyNotes(notes) {
  return JSON.stringify(notes);
}

function mergeExtractionHints(structured, extraction) {
  const hints = extraction?.documentAi?.hints;
  if (!hints || typeof hints !== 'object') {
    return structured;
  }

  const merged = { ...structured };

  if (hints.documentType && merged.documentType === 'unknown') {
    merged.documentType = hints.documentType;
    merged.classificationConfidence = Math.max(
      Number(merged.classificationConfidence || 0),
      0.85,
    );
  }

  if (hints.companyName) {
    merged.companyName = hints.companyName;
  }

  if (hints.invoiceDate && !merged.invoiceDate) {
    merged.invoiceDate = hints.invoiceDate;
  }

  if (hints.currency && (!merged.currency || merged.currency === 'MYR')) {
    merged.currency = hints.currency;
  }

  return merged;
}

function withTimeout(promise, timeoutMs, label) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${label} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    clearTimeout(timeoutId);
  });
}

async function updateDocumentStage(documentId, baseNotes, patch) {
  return documentRepository.update(documentId, {
    parsingNotes: stringifyNotes({
      ...parseNotes(baseNotes),
      ...patch,
      stageUpdatedAt: new Date().toISOString(),
    }),
  });
}

async function processUploadedDocument({
  businessId,
  file,
  createdDocument,
}) {
  let document = createdDocument;
  let extraction = null;
  let structured = null;
  let financialRecords = [];

  try {
    await updateDocumentStage(createdDocument._id, document.parsingNotes, {
      stage: 'extracting_text',
      fileName: file.originalname,
    });

    extraction = await withTimeout(
      extractDocumentText({
        mimeType: file.mimetype,
        buffer: file.buffer,
        fileName: file.originalname,
      }),
      EXTRACTION_TIMEOUT_MS,
      'Text extraction',
    );

    document = await documentRepository.update(createdDocument._id, {
      totalPages: extraction.totalPages,
      ocrRequired: extraction.ocrRequired,
      status: 'parsed',
      parsingNotes: stringifyNotes({
        extractionMethod: extraction.extractionMethod,
        extractedTextLength: extraction.rawText.length,
        documentAiProcessor: extraction.documentAi?.processorKey ?? null,
      }),
    });

    document = await updateDocumentStage(createdDocument._id, document.parsingNotes, {
      stage: 'classifying_document',
      extractionMethod: extraction.extractionMethod,
      extractedTextLength: extraction.rawText.length,
    });

    structured = await withTimeout(
      extractStructuredDocumentData({
        fileName: file.originalname,
        mimeType: file.mimetype,
        totalPages: extraction.totalPages,
        ocrRequired: extraction.ocrRequired,
        providerHints: extraction.documentAi?.hints || null,
        rawText: extraction.rawText,
      }),
      CLASSIFICATION_TIMEOUT_MS,
      'GLM classification',
    );
    structured = mergeExtractionHints(structured, extraction);

    financialRecords = await financialRecordsRepository.replaceByDocument(
      createdDocument._id,
      structured.financialRecords.map((record) => ({
        businessId,
        documentId: createdDocument._id,
        pageNumber: null,
        recordType: record.recordType,
        transactionDate: record.transactionDate,
        dueDate: record.dueDate,
        description: record.description,
        category: record.category,
        amount: record.amount,
        currency: record.currency,
        direction: record.direction,
        counterpartyName: record.counterpartyName,
        paymentMethod: record.paymentMethod,
        referenceNumber: record.referenceNumber,
        sourceDocumentType: structured.documentType,
        confidenceScore: record.confidenceScore,
        rawExtractedText: record.rawExtractedText,
      })),
    );

    document = await documentRepository.update(createdDocument._id, {
      documentType: structured.documentType,
      classificationConfidence: structured.classificationConfidence,
      companyName: structured.companyName,
      invoiceDate: structured.invoiceDate,
      statementMonth: structured.statementMonth,
      currency: structured.currency,
      status: 'classified',
      parsingNotes: stringifyNotes({
        extractionMethod: extraction.extractionMethod,
        extractedTextLength: extraction.rawText.length,
        normalizedTextLength: structured.normalizedText.length,
        financialRecordCount: financialRecords.length,
        documentAiProcessor: extraction.documentAi?.processorKey ?? null,
        documentAiEntityCount: extraction.documentAi?.entities?.length ?? 0,
        usedFallback: structured.usedFallback || false,
        fallbackReason: structured.fallbackReason ?? null,
      }),
    });

    const chunkSourceText = structured.normalizedText || extraction.rawText;
    const chunks = chunkDocumentText(chunkSourceText, {
      documentType: structured.documentType,
    });
    if (chunks.length === 0) {
      throw new Error('No chunkable text remained after extraction');
    }

    document = await documentRepository.update(createdDocument._id, {
      status: 'chunked',
      parsingNotes: stringifyNotes({
        ...parseNotes(document.parsingNotes),
        chunkCount: chunks.length,
      }),
    });

    document = await updateDocumentStage(createdDocument._id, document.parsingNotes, {
      stage: 'embedding_chunks',
      chunkCount: chunks.length,
    });

    const embeddingResult = await withTimeout(
      embedTexts(chunks.map((chunk) => chunk.text)),
      EMBEDDING_TIMEOUT_MS,
      'Chunk embedding',
    );
    const chunkRecords = await documentChunksRepository.replaceByDocument(
      createdDocument._id,
      chunks.map((chunk, index) => ({
        businessId,
        documentId: createdDocument._id,
        pageNumber: chunk.pageNumber,
        chunkIndex: chunk.chunkIndex,
        chunkType: chunk.chunkType,
        text: chunk.text,
        embedding: embeddingResult.vectors[index],
        tokenCount: chunk.tokenCount,
        metadata: {
          documentType: structured.documentType,
          companyName: structured.companyName,
          statementMonth: structured.statementMonth,
          invoiceDate: structured.invoiceDate,
        },
      })),
    );

    if (embeddingResult.available) {
      document = await documentRepository.update(createdDocument._id, {
        status: 'embedded',
        parsingNotes: stringifyNotes({
          ...parseNotes(document.parsingNotes),
          embeddingProvider: embeddingResult.provider,
          embeddingModel: embeddingResult.model,
          embeddingWarning: embeddingResult.warning ?? null,
          chunkCount: chunkRecords.length,
        }),
      });

      await documentRepository.update(createdDocument._id, {
        status: 'completed',
        parsingNotes: stringifyNotes({
          ...parseNotes(document.parsingNotes),
          chunkCount: chunkRecords.length,
          embeddingProvider: embeddingResult.provider,
          embeddingModel: embeddingResult.model,
          embeddingWarning: embeddingResult.warning ?? null,
          completedAt: new Date().toISOString(),
        }),
      });
      return;
    }

    await documentRepository.update(createdDocument._id, {
      status: 'chunked',
      parsingNotes: stringifyNotes({
        ...parseNotes(document.parsingNotes),
        chunkCount: chunkRecords.length,
        embeddingProvider: 'none',
        embeddingModel: null,
        embeddingWarning:
          embeddingResult.warning ||
          'Chunks saved, but embeddings are pending a real embedding model.',
      }),
    });
  } catch (err) {
    const parseError = err.message || 'Document parsing failed';
    await documentRepository.update(createdDocument._id, {
      status: 'failed',
      parsingNotes: parseError,
    });
    console.error(
      `[documentsRoute] background ingestion failed for ${createdDocument._id}:`,
      err,
    );
  }
}

async function deleteDocumentArtifacts({ document, objectKey }) {
  const effectiveKey =
    objectKey ||
    document?.storageKey ||
    parseObjectKeyFromStorageUrl(document?.storageUrl);

  if (effectiveKey) {
    await deleteDocument(effectiveKey);
  }

  if (document?._id) {
    await Promise.all([
      financialRecordsRepository.deleteByDocument(document._id),
      documentChunksRepository.deleteByDocument(document._id),
    ]);
    await documentRepository.remove(document._id);
  }
}

router.get('/', async (req, res) => {
  try {
    const { businessId } = req.query;

    if (!businessId) {
      return res.status(400).json(fail('businessId is required'));
    }

    if (!ObjectId.isValid(businessId)) {
      return res.status(400).json(fail('businessId must be a valid ObjectId'));
    }

    const [objects, documents] = await Promise.all([
      listDocumentsForBusiness(businessId),
      documentRepository.listByBusinessId(businessId, {
        sort: { createdAt: -1 },
      }),
    ]);
    const previewMap = await documentChunksRepository.listFirstChunkTextsByDocumentIds(
      documents.map((document) => document._id),
    );

    const documentMap = new Map(
      documents.map((document) => [
        document.storageKey ||
          parseObjectKeyFromStorageUrl(document.storageUrl) ||
          document.storageUrl,
        document,
      ]),
    );

    const objectItems = objects.map((object) => {
      const document = documentMap.get(object.key) || null;
      return {
        key: object.key,
        storageUrl: object.storageUrl,
        size: object.size,
        lastModified: object.lastModified,
        fileName: document?.fileName || object.key.split('/').pop() || 'document',
        mimeType: document?.mimeType || null,
        status: document?.status || 'uploaded',
        documentId: document?._id || null,
        documentType: document?.documentType || 'unknown',
        ocrRequired: document?.ocrRequired ?? null,
        totalPages: document?.totalPages ?? null,
        parsingNotes: document?.parsingNotes ?? null,
        chunkPreview: document?._id ? previewMap.get(String(document._id)) ?? null : null,
        createdAt: document?.createdAt || object.lastModified || null,
      };
    });

    const objectKeys = new Set(objectItems.map((item) => item.key));
    const documentOnlyItems = documents
      .filter((document) => {
        const key =
          document.storageKey ||
          parseObjectKeyFromStorageUrl(document.storageUrl);
        return key && !objectKeys.has(key);
      })
      .map((document) => ({
        key:
          document.storageKey ||
          parseObjectKeyFromStorageUrl(document.storageUrl) ||
          document.storageUrl,
        storageUrl: document.storageUrl,
        size: 0,
        lastModified: document.updatedAt || document.createdAt || null,
        fileName: document.fileName || 'document',
        mimeType: document.mimeType || null,
        status: document.status || 'uploaded',
        documentId: document._id || null,
        documentType: document.documentType || 'unknown',
        ocrRequired: document.ocrRequired ?? null,
        totalPages: document.totalPages ?? null,
        parsingNotes: document.parsingNotes ?? null,
        chunkPreview: previewMap.get(String(document._id)) ?? null,
        createdAt: document.createdAt || null,
      }));

    const items = [...objectItems, ...documentOnlyItems].sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return bTime - aTime;
    });

    return res.json(ok({ items }));
  } catch (err) {
    console.error('[GET /api/documents] error:', err);
    return res
      .status(500)
      .json(fail(err.message || 'Failed to load documents'));
  }
});

router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const { businessId } = req.body;

    if (!businessId) {
      return res
        .status(400)
        .json(fail('businessId is required'));
    }

    if (!ObjectId.isValid(businessId)) {
      return res
        .status(400)
        .json(fail('businessId must be a valid ObjectId'));
    }

    if (!req.file) {
      return res
        .status(400)
        .json(fail('file is required'));
    }

    const contentHash = computeContentHash(req.file.buffer);
    const duplicateDocument = await documentRepository.findByBusinessIdAndContentHash(
      businessId,
      contentHash,
    );

    if (duplicateDocument) {
      return res.status(409).json(
        fail(
          `Duplicate upload blocked. "${duplicateDocument.fileName}" is already registered for this business.`,
          { document: duplicateDocument },
        ),
      );
    }

    const uploadedAsset = await uploadDocument({
      businessId,
      fileName: req.file.originalname,
      mimeType: req.file.mimetype,
      buffer: req.file.buffer,
    });

    const createdDocument = await documentRepository.create({
      businessId,
      fileName: req.file.originalname,
      mimeType: req.file.mimetype,
      storageUrl: uploadedAsset.storageUrl,
      storageKey: uploadedAsset.key,
      contentHash,
      sourceType: 'upload',
      documentType: 'unknown',
      currency: 'MYR',
      ocrRequired: false,
      status: 'uploaded',
      parsingNotes: null,
    });

    setImmediate(() => {
      processUploadedDocument({
        businessId,
        file: req.file,
        createdDocument,
      }).catch((err) => {
        console.error('[documentsRoute] background ingestion crashed:', err);
      });
    });

    return res.status(201).json(
      ok({
        document: createdDocument,
        upload: {
          key: uploadedAsset.key,
          bucket: uploadedAsset.bucket,
          storageUrl: uploadedAsset.storageUrl,
        },
        extraction: null,
        structured: null,
        parseError: null,
      }),
    );
  } catch (err) {
    console.error('[POST /api/documents/upload] error:', err);
    return res
      .status(500)
      .json(fail(err.message || 'Failed to upload document'));
  }
});

router.delete('/', async (req, res) => {
  try {
    const { businessId, documentId, key } = req.query;

    if (!businessId) {
      return res.status(400).json(fail('businessId is required'));
    }

    if (!ObjectId.isValid(businessId)) {
      return res.status(400).json(fail('businessId must be a valid ObjectId'));
    }

    if (!documentId && !key) {
      return res.status(400).json(fail('documentId or key is required'));
    }

    let document = null;
    let objectKey = key ? String(key) : null;

    if (documentId) {
      if (!ObjectId.isValid(documentId)) {
        return res.status(400).json(fail('documentId must be a valid ObjectId'));
      }

      document = await documentRepository.getById(documentId);
      if (!document) {
        return res.status(404).json(fail('Document not found'));
      }

      if (String(document.businessId) !== businessId) {
        return res.status(403).json(fail('Document does not belong to this business'));
      }
    } else if (objectKey) {
      const storageUrl = buildStorageUrl(objectKey);
      document = await documentRepository.findByBusinessIdAndStorageUrl(
        businessId,
        storageUrl,
      );
    }

    objectKey =
      objectKey ||
      document?.storageKey ||
      parseObjectKeyFromStorageUrl(document?.storageUrl);

    if (!document && !objectKey) {
      return res.status(404).json(fail('Uploaded file not found'));
    }

    await deleteDocumentArtifacts({ document, objectKey });

    return res.json(
      ok({
        deleted: true,
        documentId: document?._id || null,
        key: objectKey || null,
      }),
    );
  } catch (err) {
    console.error('[DELETE /api/documents] error:', err);
    return res
      .status(500)
      .json(fail(err.message || 'Failed to delete document'));
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (!ObjectId.isValid(id)) {
      return res.status(400).json(fail('id must be a valid ObjectId'));
    }

    const document = await documentRepository.getById(id);
    if (!document) {
      return res.status(404).json(fail('Document not found'));
    }

    return res.json(ok(document));
  } catch (err) {
    console.error('[GET /api/documents/:id] error:', err);
    return res
      .status(500)
      .json(fail(err.message || 'Failed to load document'));
  }
});

router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json(fail('File exceeds 10MB limit'));
    }
    return res.status(400).json(fail(err.message));
  }

  if (err) {
    return res.status(400).json(fail(err.message));
  }

  return next();
});

module.exports = router;
