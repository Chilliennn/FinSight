const express = require('express');
const multer = require('multer');
const { ObjectId } = require('mongodb');

const documentRepository = require('../../data/repositories/documentRepository');
const { uploadDocument } = require('../../data/storage/r2Storage');

const router = express.Router();

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

function fail(error) {
  return { success: false, data: null, error };
}

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

    const uploadedAsset = await uploadDocument({
      businessId,
      fileName: req.file.originalname,
      mimeType: req.file.mimetype,
      buffer: req.file.buffer,
    });

    const document = await documentRepository.create({
      businessId,
      fileName: req.file.originalname,
      mimeType: req.file.mimetype,
      storageUrl: uploadedAsset.storageUrl,
      sourceType: 'upload',
      documentType: 'unknown',
      currency: 'MYR',
      ocrRequired: false,
      status: 'uploaded',
      parsingNotes: null,
    });

    return res.status(201).json(
      ok({
        document,
        upload: {
          key: uploadedAsset.key,
          bucket: uploadedAsset.bucket,
          storageUrl: uploadedAsset.storageUrl,
        },
      }),
    );
  } catch (err) {
    console.error('[POST /api/documents/upload] error:', err);
    return res
      .status(500)
      .json(fail(err.message || 'Failed to upload document'));
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
