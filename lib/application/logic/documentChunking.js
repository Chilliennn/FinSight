function normalizeText(text) {
  return String(text || '')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function estimateTokenCount(text) {
  const words = String(text || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
  return words === 0 ? 0 : Math.ceil(words * 1.3);
}

function cleanLine(line) {
  return String(line || '').replace(/\s+/g, ' ').trim();
}

function isLikelyHeading(line) {
  const value = cleanLine(line);
  if (!value || value.length > 90) return false;
  if (/^\d+(\.\d+)*[\).]?\s+[A-Z]/.test(value)) return true;
  if (/^[A-Z][A-Z\s&/-]{2,}$/.test(value) && value.length <= 70) return true;
  return /^(invoice|receipt|statement|summary|payment terms|terms|notes|bank account|vendor|supplier|bill to|ship to|totals?|subtotal|tax|amount due|transactions?)\b/i.test(
    value,
  );
}

function isLikelyTransactionLine(line) {
  const value = cleanLine(line);
  if (!value) return false;
  if (/^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b/.test(value)) return true;
  if (/^\d{4}-\d{2}-\d{2}\b/.test(value)) return true;
  return /(debit|credit|balance|withdrawal|deposit|transfer|payment|rm\s?\d)/i.test(
    value,
  );
}

function detectChunkType(text, documentType = 'unknown') {
  const value = cleanLine(text);
  if (!value) return 'paragraph';

  if (isLikelyHeading(value)) return 'header';
  if (documentType === 'bank_statement' && isLikelyTransactionLine(value)) {
    return 'table';
  }
  if (documentType === 'contract' && /^\d+(\.\d+)*[\).]?\s+/.test(value)) {
    return 'section';
  }
  if (/\b(total|subtotal|tax|amount due|balance)\b/i.test(value)) {
    return 'section';
  }

  return 'paragraph';
}

function splitBlocks(text) {
  return normalizeText(text)
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean);
}

function splitContractBlock(block) {
  const lines = block
    .split('\n')
    .map((line) => cleanLine(line))
    .filter(Boolean);

  if (lines.length <= 1) {
    return [block];
  }

  const parts = [];
  let current = [];

  for (const line of lines) {
    const startsNewClause =
      /^\d+(\.\d+)*[\).]?\s+/.test(line) ||
      (/^[A-Z][A-Z\s&/-]{2,}$/.test(line) && line.length <= 70);

    if (startsNewClause && current.length > 0) {
      parts.push(current.join('\n'));
      current = [line];
      continue;
    }

    current.push(line);
  }

  if (current.length > 0) {
    parts.push(current.join('\n'));
  }

  return parts;
}

function splitBankStatementBlock(block) {
  const lines = block
    .split('\n')
    .map((line) => cleanLine(line))
    .filter(Boolean);

  if (lines.length <= 6) {
    return [block];
  }

  const transactionLines = lines.filter((line) => isLikelyTransactionLine(line));
  if (transactionLines.length < Math.max(3, Math.floor(lines.length * 0.4))) {
    return [block];
  }

  const parts = [];
  let buffer = [];

  for (const line of lines) {
    if (isLikelyHeading(line) && buffer.length > 0) {
      parts.push(buffer.join('\n'));
      buffer = [line];
      continue;
    }

    buffer.push(line);

    if (
      buffer.length >= 8 &&
      isLikelyTransactionLine(line)
    ) {
      parts.push(buffer.join('\n'));
      buffer = [];
    }
  }

  if (buffer.length > 0) {
    parts.push(buffer.join('\n'));
  }

  return parts;
}

function splitInvoiceReceiptBlock(block) {
  const lines = block
    .split('\n')
    .map((line) => cleanLine(line))
    .filter(Boolean);

  if (lines.length <= 5) {
    return [block];
  }

  const parts = [];
  let current = [];

  for (const line of lines) {
    const boundary =
      (isLikelyHeading(line) && current.length > 0) ||
      (/^(subtotal|tax|total|amount due|payment terms|notes?)\b/i.test(line) &&
        current.length > 0);

    if (boundary) {
      parts.push(current.join('\n'));
      current = [line];
      continue;
    }

    current.push(line);
  }

  if (current.length > 0) {
    parts.push(current.join('\n'));
  }

  return parts;
}

function extractStructuralUnits(text, documentType = 'unknown') {
  const blocks = splitBlocks(text);
  const units = [];

  for (const block of blocks) {
    let segments = [block];

    if (documentType === 'contract') {
      segments = splitContractBlock(block);
    } else if (documentType === 'bank_statement') {
      segments = splitBankStatementBlock(block);
    } else if (documentType === 'invoice' || documentType === 'receipt') {
      segments = splitInvoiceReceiptBlock(block);
    }

    for (const segment of segments) {
      const normalizedSegment = normalizeText(segment);
      if (!normalizedSegment) continue;

      units.push({
        text: normalizedSegment,
        chunkType: detectChunkType(
          normalizedSegment.split('\n')[0] || normalizedSegment,
          documentType,
        ),
        pageNumber: null,
      });
    }
  }

  return units;
}

function splitIntoSentences(text) {
  const normalized = normalizeText(text);
  if (!normalized) return [];

  const abbreviations = new Set([
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'inc',
    'ltd',
    'sdn',
    'bhd',
    'no',
    'ref',
    'inv',
    'acct',
    'fig',
    'etc',
  ]);

  const sentences = [];
  let current = '';

  for (let index = 0; index < normalized.length; index += 1) {
    const char = normalized[index];
    current += char;

    if (char === '\n') {
      const next = normalized[index + 1];
      if (next === '\n') {
        const sentence = current.trim();
        if (sentence) sentences.push(sentence);
        current = '';
      }
      continue;
    }

    if (!'.!?;'.includes(char)) {
      continue;
    }

    const previousToken = current
      .slice(0, -1)
      .trim()
      .split(/\s+/)
      .pop()
      ?.replace(/[^a-zA-Z]/g, '')
      .toLowerCase();

    const nextChar = normalized[index + 1] || '';
    const decimalNumberBoundary = /\d/.test(normalized[index - 1] || '') && /\d/.test(nextChar);
    if (decimalNumberBoundary) {
      continue;
    }

    if (char === '.' && previousToken && abbreviations.has(previousToken)) {
      continue;
    }

    const lookAhead = normalized.slice(index + 1).match(/^\s*([A-Za-z0-9"('])?/);
    const boundaryToken = lookAhead?.[1] || '';
    const isBoundary =
      !boundaryToken ||
      /[A-Z0-9"(']/.test(boundaryToken) ||
      char === ';';

    if (isBoundary) {
      const sentence = current.trim();
      if (sentence) sentences.push(sentence);
      current = '';
    }
  }

  const tail = current.trim();
  if (tail) {
    sentences.push(tail);
  }

  return sentences;
}

function splitByClauses(text) {
  return String(text || '')
    .split(/(?<=[,;:])\s+|\n+/)
    .map((part) => cleanLine(part))
    .filter(Boolean);
}

function splitByWords(text, maxChars) {
  const words = String(text || '').split(/\s+/).filter(Boolean);
  const parts = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length > maxChars && current) {
      parts.push(current);
      current = word;
      continue;
    }
    current = candidate;
  }

  if (current) {
    parts.push(current);
  }

  return parts;
}

function splitOversizedUnitText(text, maxChars) {
  const sentences = splitIntoSentences(text);
  if (sentences.length <= 1) {
    const clauses = splitByClauses(text);
    if (clauses.length > 1) {
      return clauses.flatMap((clause) =>
        clause.length > maxChars ? splitByWords(clause, maxChars) : [clause],
      );
    }
    return splitByWords(text, maxChars);
  }

  const parts = [];
  let current = '';

  for (const sentence of sentences) {
    if (sentence.length > maxChars) {
      if (current) {
        parts.push(current);
        current = '';
      }

      const clauses = splitByClauses(sentence);
      if (clauses.length > 1) {
        parts.push(
          ...clauses.flatMap((clause) =>
            clause.length > maxChars ? splitByWords(clause, maxChars) : [clause],
          ),
        );
      } else {
        parts.push(...splitByWords(sentence, maxChars));
      }
      continue;
    }

    const candidate = current ? `${current} ${sentence}` : sentence;
    if (candidate.length > maxChars && current) {
      parts.push(current);
      current = sentence;
      continue;
    }

    current = candidate;
  }

  if (current) {
    parts.push(current);
  }

  return parts;
}

function expandOversizedUnits(units, maxChars) {
  return units.flatMap((unit) => {
    if (unit.text.length <= maxChars) {
      return [unit];
    }

    return splitOversizedUnitText(unit.text, maxChars).map((part) => ({
      ...unit,
      text: part,
    }));
  });
}

function takeOverlapSentences(text, overlapSentences) {
  const sentences = splitIntoSentences(text);
  if (sentences.length <= overlapSentences) {
    return sentences.join(' ');
  }

  return sentences.slice(sentences.length - overlapSentences).join(' ');
}

function mergeChunkType(currentType, nextType) {
  if (!currentType) return nextType || 'paragraph';
  if (!nextType || currentType === nextType) return currentType;
  if (currentType === 'header') return nextType;
  return 'section';
}

function chunkDocumentText(text, options = {}) {
  const normalizedText = normalizeText(text);
  if (!normalizedText) {
    return [];
  }

  const documentType = options.documentType || 'unknown';
  const maxChars = options.maxChars ?? 2400;
  const overlapSentences = options.overlapSentences ?? 2;

  const structuralUnits = extractStructuralUnits(normalizedText, documentType);
  const units = expandOversizedUnits(structuralUnits, maxChars);

  if (units.length === 0) {
    return [];
  }

  const chunks = [];
  let currentText = '';
  let currentChunkType = null;

  for (const unit of units) {
    const candidate = currentText ? `${currentText}\n\n${unit.text}` : unit.text;

    if (candidate.length > maxChars && currentText) {
      chunks.push({
        chunkType: currentChunkType || 'paragraph',
        text: currentText,
        pageNumber: null,
      });

      const overlapText = takeOverlapSentences(currentText, overlapSentences);
      const restartedChunk = overlapText ? `${overlapText}\n\n${unit.text}` : unit.text;
      currentText = restartedChunk.length > maxChars ? unit.text : restartedChunk;
      currentChunkType = unit.chunkType || 'paragraph';
      continue;
    }

    currentText = candidate;
    currentChunkType = mergeChunkType(currentChunkType, unit.chunkType);
  }

  if (currentText) {
    chunks.push({
      chunkType: currentChunkType || 'paragraph',
      text: currentText,
      pageNumber: null,
    });
  }

  return chunks.map((chunk, index) => ({
    chunkIndex: index,
    chunkType: chunk.chunkType,
    text: chunk.text,
    tokenCount: estimateTokenCount(chunk.text),
    pageNumber: chunk.pageNumber,
  }));
}

module.exports = {
  chunkDocumentText,
  estimateTokenCount,
  normalizeText,
};
