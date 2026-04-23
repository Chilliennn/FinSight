# AI Document Ingestion Pipeline for SME Financial App (GLM-5.1 Text-Only Version)

## Goal

Build a document ingestion pipeline that accepts messy financial documents such as PDFs and images, but is designed around the limitation that **the available model is ILMU GLM-5.1 only**.

Because this model should be treated as **text-first, not a vision/OCR model**, the pipeline must separate:

- **document reading / OCR**
- **text cleaning**
- **AI extraction from text**
- **database storage**

The final output should still be:

- `documents` records for file-level metadata and ingestion tracking
- `financial_records` for structured numeric facts used by the decision engine
- `document_chunks` for text retrieval, explanations, and evidence grounding

---

## Core Idea

Since GLM-5.1 cannot be relied on to directly read PDFs/images like a multimodal vision model, the pipeline should use:

- **traditional PDF text extraction** whenever possible
- **traditional OCR** for scanned PDFs/images
- **GLM-5.1 only after text has already been extracted**

So the model is used for what it can still do well:

- document classification from extracted text
- metadata extraction from extracted text
- structured financial record extraction from extracted text
- text normalization and cleanup
- optional categorization and mapping

This is the safest design under the model constraint.

---

## High-Level Pipeline

```text
User uploads file
→ Store original file
→ Create documents record
→ Detect whether file already contains machine-readable text
→ If yes: extract text directly
→ If no: run OCR using non-AI OCR tool
→ Send extracted text to GLM-5.1
→ GLM-5.1 performs classification + metadata extraction + financial record extraction
→ Save extracted metadata back to documents
→ Save structured items to financial_records
→ Take cleaned full text
→ Split into chunks
→ Generate embeddings
→ Save chunks to document_chunks
→ Mark document as completed
```

---

## Main Constraint

The most important design rule is:

**Do not depend on GLM-5.1 to read raw images or PDFs directly.**

Instead:

- use parser/OCR to produce text first
- then use GLM-5.1 on that text

This avoids wasting time trying to force the model to do something it is not good at.

---

## What GLM-5.1 Should Do

Use GLM-5.1 for:

- classify document type from extracted text
- extract metadata from extracted text
- extract financial facts from extracted text
- normalize noisy OCR output into cleaner text
- convert messy text into strict JSON format

Examples of tasks suitable for GLM-5.1:

- determine whether a document is an invoice, receipt, bank statement, or contract
- identify company name, invoice date, statement month, currency
- extract payment amount, due date, inflow/outflow, reference number
- convert OCR text into a normalized readable version
- organize extracted values into your schema format

---

## What GLM-5.1 Should NOT Do

Do not rely on GLM-5.1 for:

- reading image pixels directly
- OCR from screenshots, scanned PDFs, or receipts
- precise table extraction from raw document layouts
- direct PDF/image ingestion without a text extraction step

These tasks should be handled before the model call.

---

## Collections Used

### 1. `documents`
Stores file-level metadata and ingestion status.

Used for:
- uploaded file tracking
- document type
- company name
- invoice/statement dates
- pipeline status

### 2. `financial_records`
Stores structured extracted facts.

Used by your teammate for:
- cash flow analysis
- inflow/outflow computation
- overdue payment detection
- financial decision generation

### 3. `document_chunks`
Stores chunked text plus embeddings.

Used for:
- retrieval-augmented generation (RAG)
- explanations
- evidence grounding
- contract terms and vendor notes

---

## Detailed Step-by-Step Pipeline

## Step 1: Upload and Store Original File

When the user uploads a PDF or image:

1. save the original file to storage such as S3, Firebase Storage, or Cloudinary
2. create an initial record in `documents`

Suggested initial document fields:

- `businessId`
- `fileName`
- `mimeType`
- `storageUrl`
- `sourceType = "upload"`
- `status = "uploaded"`
- `createdAt`

Example:

```json
{
  "businessId": "ObjectId(...)",
  "fileName": "march_invoice.pdf",
  "mimeType": "application/pdf",
  "storageUrl": "https://...",
  "sourceType": "upload",
  "status": "uploaded"
}
```

---

## Step 2: Detect Whether the File Already Contains Text

Before using OCR, check the file type:

### If the file is a normal PDF with selectable text
Use a PDF text extraction library.

Examples:
- `pdf-parse`
- `pdfjs`
- other standard PDF parsers

### If the file is an image or scanned PDF
Use a separate OCR tool first.

Examples:
- Tesseract
- cloud OCR service
- any OCR engine allowed in your stack

### Why this step matters

You should not waste OCR effort on files that already contain selectable text.

This keeps the pipeline simpler and more accurate.

---

## Step 3: Extract Raw Text

At the end of this step, you should have:

- `rawText`
- optionally `pageTexts`
- maybe `totalPages`

This is the first major handoff point in the pipeline.

### Output example

```json
{
  "rawText": "Invoice No: INV-1003\nSupplier: ABC Trading\nTotal: RM 850.00\nDue Date: 24/04/2026",
  "pageTexts": [
    "Invoice No: INV-1003\nSupplier: ABC Trading\nTotal: RM 850.00\nDue Date: 24/04/2026"
  ],
  "totalPages": 1,
  "ocrRequired": false
}
```

---

## Step 4: Send Extracted Text to GLM-5.1

Now use GLM-5.1 for the tasks it is actually good at.

Give it:

- extracted text
- a strict JSON schema target
- clear enums
- instructions to return JSON only

### What the model should return

Ask the model to return strict JSON in this shape:

```json
{
  "documentType": "invoice",
  "classificationConfidence": 0.97,
  "companyName": "ABC Supplies Sdn Bhd",
  "invoiceDate": "2026-04-10",
  "statementMonth": null,
  "currency": "MYR",
  "normalizedText": "Invoice number INV-2041. Supplier ABC Supplies Sdn Bhd. Total RM 1,850.50. Due date 24 April 2026.",
  "financialRecords": [
    {
      "recordType": "invoice_payable",
      "transactionDate": "2026-04-10",
      "dueDate": "2026-04-24",
      "description": "Office supplies",
      "category": "inventory",
      "amount": 1850.50,
      "currency": "MYR",
      "direction": "outflow",
      "counterpartyName": "ABC Supplies Sdn Bhd",
      "paymentMethod": null,
      "referenceNumber": "INV-2041",
      "confidenceScore": 0.94,
      "rawExtractedText": "Invoice total RM 1,850.50 due on 24 April 2026"
    }
  ]
}
```

### Why this works

GLM-5.1 is much more suitable for:

- reading already-extracted text
- organizing it
- classifying it
- turning it into clean JSON

This means you still get strong value from the model without depending on OCR capability.

---

## Step 5: Validate and Normalize Model Output

Never write model output directly to the database without checking it.

Backend should validate:

- required JSON keys exist
- `documentType` is one of your allowed enum values
- dates are parseable
- amounts are numeric
- `direction` is either `inflow` or `outflow`
- arrays are properly shaped

If validation fails:

- mark `documents.status = "failed"`
- save a useful error note in `parsingNotes`

If validation succeeds:

- continue the pipeline

### Important note

Because OCR text may be noisy, your validation layer is very important.

The model may infer fields incorrectly if OCR quality is poor, so the system must not blindly trust output.

---

## Step 6: Update the `documents` Collection

Use the parser/OCR result plus model result to update file-level metadata:

From parser/OCR:
- `totalPages`
- `ocrRequired`

From GLM-5.1:
- `documentType`
- `classificationConfidence`
- `companyName`
- `invoiceDate`
- `statementMonth`
- `currency`

Also update:
- `status = "classified"` or `status = "parsed"`

Suggested sequence:

- after upload → `uploaded`
- after text extraction succeeds → `parsed`
- after GLM-5.1 extraction succeeds → `classified`
- after chunks and embeddings saved → `completed`

---

## Step 7: Save Structured Records into `financial_records`

Take `financialRecords` returned by GLM-5.1 and insert one document per extracted fact.

Each record should include:

- `businessId`
- `documentId`
- `pageNumber` if available
- `recordType`
- `transactionDate`
- `dueDate`
- `description`
- `category`
- `amount`
- `currency`
- `direction`
- `counterpartyName`
- `paymentMethod`
- `referenceNumber`
- `sourceDocumentType`
- `confidenceScore`
- `rawExtractedText`
- `createdAt`

### Why this matters

Your teammate should not have to re-read OCR text every time she wants to calculate:

- upcoming outflows
- overdue invoices
- monthly burn
- recurring expenses
- cash flow risk in the next 6 weeks

She should be able to query `financial_records` directly.

---

## Step 8: Prepare Text for Chunking

For `document_chunks`, use the best available text source:

### Preferred order
1. `normalizedText` returned by GLM-5.1
2. original extracted `rawText`
3. per-page text joined together

Why prefer normalized text:

- OCR output can be messy
- normalized text is easier to chunk
- retrieval quality improves if text is cleaner

### Important warning

Do not let the model rewrite the meaning too aggressively.

The normalized text should remain faithful to the source.

---

## Step 9: Chunk the Text

Split text into chunks for retrieval and explanation.

Even though GLM-5.1 already extracted structured facts, chunking is still necessary because:

- contracts contain payment terms
- invoice notes may contain penalties or conditions
- vendor notes may explain unusual charges
- explanations need evidence grounding

### Recommended chunking strategy

Because the model is text-only, use a simple and dependable chunking strategy:

- start with paragraph-based splitting
- if a paragraph is too large, further split by character or token size
- keep chunk size around 500 to 800 tokens
- overlap 50 to 100 tokens

### Document-specific guidance

- invoices and receipts: split by sections or table blocks if obvious from extracted text
- bank statements: split by page or transaction blocks
- contracts: split by headings and paragraphs

---

## Step 10: Generate Embeddings for Each Chunk

For every chunk:

1. call embedding model
2. receive embedding vector
3. save the vector in `document_chunks`

Each chunk record should contain:

- `businessId`
- `documentId`
- `pageNumber`
- `chunkIndex`
- `chunkType`
- `text`
- `embedding`
- `tokenCount`
- `metadata.documentType`
- `metadata.companyName`
- `metadata.statementMonth`
- `metadata.invoiceDate`
- `createdAt`

### Why `document_chunks` still matters

`financial_records` only stores structured facts.

But many important details only exist in text, such as:

- payment terms
- late penalties
- suspension clauses
- vendor notes
- explanations for charges

`document_chunks` gives the AI system evidence and context so it can explain *why* a risk exists, not just compute that it exists.

---

## Step 11: Mark Ingestion Complete

Once the metadata, financial records, and chunks are all stored successfully:

- update `documents.status = "completed"`
- set `updatedAt`

If something fails at any stage:

- set `status = "failed"`
- save an error note in `parsingNotes`

---

## Recommended Status Flow

Use this status progression:

```text
uploaded
→ parsed
→ classified
→ chunked
→ embedded
→ completed
```

If any stage fails:

```text
failed
```

This is simple and clear for a hackathon implementation.

---

## What GLM-5.1 Should Handle vs What Your Backend Should Handle

## GLM-5.1 should handle

- document classification from text
- metadata extraction from text
- financial record extraction from text
- normalization of messy OCR output into cleaner text
- converting extracted content into strict JSON

## Backend should handle

- file upload
- file storage
- PDF text extraction
- OCR for scanned files/images
- collection writes
- schema validation
- status tracking
- chunk splitting
- embedding calls
- retries and error handling

This is the correct split under the model limitation.

---

## Practical Prompting Strategy for GLM-5.1

Use one strong extraction prompt after text extraction.

### Suggested prompt idea

```text
You are a financial document extraction engine.

You will receive text extracted from a financial document. The text may come from PDF parsing or OCR and may contain formatting noise.

Tasks:
1. Determine the document type.
2. Extract high-level metadata.
3. Extract all structured financial records that could affect cash flow.
4. Return a cleaned but faithful normalizedText field.
5. Return valid JSON only.

Rules:
- documentType must be one of: invoice, receipt, bank_statement, contract, unknown
- direction must be one of: inflow, outflow
- recordType must be one of: income, expense, bank_transaction, invoice_payable, invoice_receivable
- currency should use ISO-style format when possible, e.g. MYR
- if a field is missing, return null
- do not include markdown
- do not include explanation outside JSON
- do not invent values that are not supported by the provided text
```

### Input to provide

```text
RAW EXTRACTED TEXT:
[paste OCR/PDF text here]
```

This is a much more realistic prompt design for GLM-5.1 than trying to send the raw document itself.

---

## Recommended MVP Scope

Do not try to perfect every document type on day one.

### Build in this order

1. invoice
2. receipt
3. bank statement
4. contract

Why this order:

- invoices and receipts are easier
- bank statements are more table-heavy
- contracts are more text-heavy

This lets you demo value quickly.

---

## Recommended Ingestion Service Flow

Create one main service such as:

```text
ingestDocument(file, businessId)
```

It should do:

1. store file
2. create `documents` row
3. extract text using parser or OCR
4. call GLM-5.1 on extracted text
5. validate result
6. update `documents`
7. insert `financial_records`
8. chunk `normalizedText` or `rawText`
9. generate embeddings
10. insert `document_chunks`
11. mark document completed

This single orchestrator keeps your code clean.

---

## Minimal Node.js Function Structure

```js
async function ingestDocument({ businessId, fileName, mimeType, fileBuffer }) {
  // 1. upload file to storage
  // 2. create documents record
  // 3. detect if file has machine-readable text
  // 4. if yes, parse PDF text
  // 5. if no, run OCR
  // 6. call GLM-5.1 using extracted text
  // 7. validate model JSON
  // 8. update documents metadata
  // 9. insert financial_records
  // 10. chunk normalizedText/rawText
  // 11. generate embeddings
  // 12. insert document_chunks
  // 13. mark completed
}
```

---

## Why This Still Helps Your Teammate

After your ingestion pipeline is complete, your teammate still does not need to work with raw PDFs directly.

She can use:

### `financial_records`
for:
- inflow/outflow calculations
- future due payments
- recurring expense trends
- cash flow forecasting

### `document_chunks`
for:
- evidence retrieval
- explanation generation
- grounding recommendations in contract or invoice text

So even with a weaker model, the system architecture still cleanly separates ingestion from decision generation.

---

## Final Recommendation

For this hackathon, do not try to force GLM-5.1 into being a vision model.

Use it where it adds the most value:

- text understanding
- classification
- metadata extraction
- structured financial extraction
- normalization

And use traditional tools for what they are better at:

- PDF parsing
- OCR
- page extraction

The winning architecture under this constraint is:

**traditional extraction first, then GLM-5.1 for intelligent structuring.**

---

## Deliverables You Should Build Next

1. file upload endpoint
2. text extraction module
3. OCR fallback module
4. `ingestDocument()` service
5. GLM-5.1 extraction prompt
6. JSON validator
7. financial record insertion logic
8. text chunker
9. embedding generator
10. document chunk insertion logic
11. status update logic

If those 11 pieces work, your ingestion part is done.
