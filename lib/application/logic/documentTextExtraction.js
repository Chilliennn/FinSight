const fs = require('fs/promises');
const os = require('os');
const path = require('path');

const { PDFParse } = require('pdf-parse');
const {
  isConfigured: isDocumentAiConfigured,
  processDocumentWithDocumentAi,
} = require('../ai-engine/documentAi.engine');

let ocrInstancePromise;
let ocrModulePromise;

async function loadOcrModule() {
  if (!ocrModulePromise) {
    ocrModulePromise = import('@gutenye/ocr-node');
  }
  return ocrModulePromise;
}

async function getOcr() {
  if (!ocrInstancePromise) {
    ocrInstancePromise = loadOcrModule().then(async (module) => {
      const Ocr = module?.default || module?.Ocr || module;
      if (!Ocr || typeof Ocr.create !== 'function') {
        throw new Error('OCR module did not expose Ocr.create()');
      }
      return Ocr.create();
    });
  }
  return ocrInstancePromise;
}

function normalizeExtractedText(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

async function withTempFile(buffer, extension, callback) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'finsight-doc-'));
  const tempPath = path.join(tempDir, `source${extension}`);

  try {
    await fs.writeFile(tempPath, buffer);
    return await callback(tempPath);
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

async function runOcrOnImagePath(imagePath) {
  const ocr = await getOcr();
  const lines = await ocr.detect(imagePath);
  return normalizeExtractedText(
    (lines || [])
      .map((line) => line?.text || '')
      .filter(Boolean)
      .join('\n'),
  );
}

async function extractTextFromImageBuffer(buffer, extension) {
  const rawText = await withTempFile(buffer, extension, runOcrOnImagePath);
  return {
    rawText,
    totalPages: 1,
    ocrRequired: true,
    extractionMethod: 'ocr_image',
  };
}

async function extractTextFromPdfBuffer(buffer) {
  const parser = new PDFParse({ data: buffer });

  try {
    const [infoResult, textResult] = await Promise.all([
      parser.getInfo({ parsePageInfo: true }),
      parser.getText(),
    ]);

    const rawText = normalizeExtractedText(textResult?.text || '');
    const totalPages = infoResult?.total || null;

    if (rawText.length >= 40) {
      return {
        rawText,
        totalPages,
        ocrRequired: false,
        extractionMethod: 'pdf_text',
      };
    }

    const screenshotResult = await parser.getScreenshot({ scale: 1.5 });
    const pages = screenshotResult?.pages || [];
    const pageTexts = [];

    for (const page of pages) {
      if (!page?.data) continue;
      const pageText = await withTempFile(
        Buffer.from(page.data),
        '.png',
        runOcrOnImagePath,
      );
      if (pageText) {
        pageTexts.push(pageText);
      }
    }

    return {
      rawText: normalizeExtractedText(pageTexts.join('\n\n')),
      totalPages: totalPages || pages.length || null,
      ocrRequired: true,
      extractionMethod: 'ocr_scanned_pdf',
    };
  } finally {
    await parser.destroy();
  }
}

async function extractDocumentText({ mimeType, buffer, fileName }) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('Document buffer is empty');
  }

  if (isDocumentAiConfigured()) {
    try {
      const result = await processDocumentWithDocumentAi({ mimeType, buffer, fileName });
      if (result.rawText) {
        return result;
      }
      console.warn('[documentTextExtraction] Document AI returned empty text, falling back to legacy extraction');
    } catch (error) {
      console.warn(
        '[documentTextExtraction] Document AI failed, falling back to legacy extraction:',
        error.message,
      );
    }
  }

  if (mimeType === 'application/pdf') {
    return extractTextFromPdfBuffer(buffer);
  }

  if (mimeType === 'image/png') {
    return extractTextFromImageBuffer(buffer, '.png');
  }

  if (mimeType === 'image/jpeg') {
    return extractTextFromImageBuffer(buffer, '.jpg');
  }

  const lowerName = String(fileName || '').toLowerCase();
  if (lowerName.endsWith('.png')) {
    return extractTextFromImageBuffer(buffer, '.png');
  }
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return extractTextFromImageBuffer(buffer, '.jpg');
  }

  throw new Error(`Unsupported mimeType for extraction: ${mimeType}`);
}

module.exports = {
  extractDocumentText,
};
