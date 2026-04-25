import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/document_upload_repository.dart';
import '../shared/custom_toast.dart';

class UploadPage extends StatefulWidget {
  final String businessId;
  final String businessName;

  const UploadPage({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  static const Color _ink = Color(0xFF020817);
  static const Color _surface = Color(0xFFF8FAFC);

  final DocumentUploadRepository _repository = DocumentUploadRepository();

  bool _isUploading = false;
  bool _isLoadingDocuments = true;
  String? _error;
  String? _documentsError;
  UploadedDocumentResult? _uploadedDocument;
  List<UploadedDocumentListItem> _documents = [];
  final Set<String> _deletingDocumentKeys = <String>{};
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _documentsError = null;
      _isLoadingDocuments = true;
    });

    try {
      final documents = await _repository.fetchDocuments(widget.businessId);
      if (!mounted) return;
      UploadedDocumentResult? latestUploadedDocument = _uploadedDocument;
      if (_uploadedDocument != null) {
        for (final document in documents) {
          if (document.documentId == _uploadedDocument!.id) {
            latestUploadedDocument = UploadedDocumentResult(
              id: _uploadedDocument!.id,
              fileName: document.fileName,
              mimeType: document.mimeType ?? _uploadedDocument!.mimeType,
              status: document.status,
              storageUrl: document.storageUrl,
            );
            break;
          }
        }
      }
      setState(() {
        _documents = documents;
        _uploadedDocument = latestUploadedDocument;
        _isLoadingDocuments = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _documentsError = err.toString().replaceFirst('Exception: ', '');
        _isLoadingDocuments = false;
      });
    }
  }

  Future<void> _browseAndUpload() async {
    setState(() {
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      setState(() {
        _selectedFile = file;
        _isUploading = true;
        _uploadedDocument = null;
      });

      final uploaded = await _repository.uploadDocument(
        businessId: widget.businessId,
        file: file,
      );

      if (!mounted) return;
      setState(() {
        _uploadedDocument = uploaded;
        _isUploading = false;
      });

      CustomToast.show(
        context: context,
        title: 'Upload Started',
        content:
            '${file.name} uploaded. Processing has started in the background.',
        type: ToastType.success,
      );

      await _loadDocuments();
      await _trackDocumentStatus(uploaded.id);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = err.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _trackDocumentStatus(String documentId) async {
    const terminalStatuses = <String>{
      'complete',
      'completed',
      'failed',
      'chunked',
      'embedded',
    };

    for (var attempt = 0; attempt < 60; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      try {
        final status = await _repository.fetchDocumentStatus(documentId);
        if (!mounted) return;

        if (_uploadedDocument != null && _uploadedDocument!.id == documentId) {
          setState(() {
            _uploadedDocument = UploadedDocumentResult(
              id: _uploadedDocument!.id,
              fileName: _uploadedDocument!.fileName,
              mimeType: _uploadedDocument!.mimeType,
              status: status.status,
              storageUrl: _uploadedDocument!.storageUrl,
            );
          });
        }

        if (terminalStatuses.contains(status.status)) {
          await _loadDocuments();
          if (!mounted) return;

          final message = status.status == 'failed'
              ? (status.parsingNotes?.isNotEmpty == true
                  ? 'Processing failed: ${status.parsingNotes}'
                  : 'Processing failed for the uploaded document.')
              : 'Document processing reached "${status.status}".';

          CustomToast.show(
            context: context,
            title: status.status == 'failed'
                ? 'Processing Failed'
                : 'Processing Updated',
            content: message,
            type: status.status == 'failed'
                ? ToastType.error
                : ToastType.success,
          );
          return;
        }

        if (attempt == 0 && status.stage != null && mounted) {
          CustomToast.show(
            context: context,
            title: 'Processing Stage',
            content: 'Processing stage: ${status.stage}',
            type: ToastType.info,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (_) {
        await _loadDocuments();
        continue;
      }
    }

    if (!mounted) return;
    await _loadDocuments();
  }

  String _documentIdentityKey(UploadedDocumentListItem item) {
    return item.documentId?.isNotEmpty == true
        ? item.documentId!
        : item.key;
  }

  Future<void> _deleteDocument(UploadedDocumentListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete uploaded file?'),
          content: Text(
            'This will remove ${item.fileName} from Cloudflare R2 and delete any extracted financial records linked to it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final identityKey = _documentIdentityKey(item);
    setState(() {
      _documentsError = null;
      _deletingDocumentKeys.add(identityKey);
    });

    try {
      await _repository.deleteDocument(
        businessId: widget.businessId,
        documentId: item.documentId,
        key: item.key,
      );

      if (!mounted) return;
      setState(() {
        _deletingDocumentKeys.remove(identityKey);
      });
      await _loadDocuments();

      if (!mounted) return;
      CustomToast.show(
        context: context,
        title: 'File Deleted',
        content: '${item.fileName} deleted.',
        type: ToastType.success,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _deletingDocumentKeys.remove(identityKey);
        _documentsError = err.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  UploadedDocumentListItem? _uploadedDocumentListItem() {
    final uploadedDocument = _uploadedDocument;
    if (uploadedDocument == null) {
      return null;
    }

    for (final item in _documents) {
      if (item.documentId == uploadedDocument.id) {
        return item;
      }
    }

    return null;
  }

  String _uploadedDocumentStatus() {
    return _uploadedDocumentListItem()?.status ?? _uploadedDocument?.status ?? 'uploaded';
  }

  Color _cardLeadingColor(String status) {
    switch (status) {
      case 'failed':
        return const Color(0xFFB91C1C);
      case 'complete':
      case 'completed':
      case 'chunked':
      case 'embedded':
      case 'classified':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _cardTrailing(String status) {
    switch (status) {
      case 'failed':
        return const Icon(
          Icons.error_outline,
          color: Color(0xFFEF4444),
          size: 22,
        );
      case 'complete':
      case 'completed':
      case 'chunked':
      case 'embedded':
      case 'classified':
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF10B981),
          size: 22,
        );
      default:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.3),
        );
    }
  }

  String _uploadedDocumentSubtitle() {
    final uploadedDocument = _uploadedDocument;
    if (uploadedDocument == null) {
      return '';
    }

    final latestDocument = _uploadedDocumentListItem();
    final status = latestDocument?.status ?? uploadedDocument.status;

    if (status == 'failed') {
      final failureReason = latestDocument?.parsingNotes?.trim();
      if (failureReason != null && failureReason.isNotEmpty) {
        return '${uploadedDocument.fileName} failed during processing: $failureReason';
      }
      return '${uploadedDocument.fileName} failed during processing.';
    }

    if (status == 'uploaded' || status == 'parsed') {
      return '${uploadedDocument.fileName} uploaded successfully. Processing is still running in the background.';
    }

    return '${uploadedDocument.fileName} stored successfully with status "$status"';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 36, 28, 40),
        children: [
          const Text(
            'Upload Financial Documents',
            style: TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Upload bank statements, invoices, or receipts in PDF or image format. AI will extract and structure all financial data automatically.',
            style: TextStyle(
              color: Color(0xFF536583),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 34),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FormatChip(
                icon: Icons.description_outlined,
                label: 'PDF Bank Statements',
                color: Color(0xFF2563EB),
                background: Color(0xFFEFF6FF),
                border: Color(0xFFBFDBFE),
              ),
              _FormatChip(
                icon: Icons.receipt_long_outlined,
                label: 'PDF Invoices',
                color: Color(0xFF7C3AED),
                background: Color(0xFFFAF5FF),
                border: Color(0xFFE9D5FF),
              ),
              _FormatChip(
                icon: Icons.image_outlined,
                label: 'JPG/PNG Receipts',
                color: Color(0xFF059669),
                background: Color(0xFFECFDF5),
                border: Color(0xFFA7F3D0),
              ),
              _FormatChip(
                icon: null,
                label: 'Max 15MB per file',
                color: Color(0xFF475569),
                background: Color(0xFFF8FAFC),
                border: Color(0xFFE2E8F0),
              ),
            ],
          ),
          const SizedBox(height: 34),
          _DropZone(
            isUploading: _isUploading,
            onBrowse: _browseAndUpload,
          ),
          if (_selectedFile != null || _uploadedDocument != null || _error != null)
            const SizedBox(height: 20),
          if (_selectedFile != null)
            _UploadStatusCard(
              title: _selectedFile!.name,
              subtitle: _isUploading
                  ? 'Uploading and queueing ingestion for ${widget.businessName}'
                  : 'Selected ${_formatFileSize(_selectedFile!.size)}',
              leadingColor: _isUploading
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF0F172A),
              trailing: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : Text(
                      _formatFileSize(_selectedFile!.size),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          if (_uploadedDocument != null) ...[
            const SizedBox(height: 12),
            _UploadStatusCard(
              title: _uploadedDocumentStatus() == 'failed'
                  ? 'Document processing failed'
                  : 'Document uploaded',
              subtitle: _uploadedDocumentSubtitle(),
              leadingColor: _cardLeadingColor(_uploadedDocumentStatus()),
              trailing: _cardTrailing(_uploadedDocumentStatus()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _UploadStatusCard(
              title: 'Upload failed',
              subtitle: _error!,
              leadingColor: const Color(0xFFB91C1C),
              trailing: const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _DocumentHistorySection(
            isLoading: _isLoadingDocuments,
            error: _documentsError,
            documents: _documents,
            onRefresh: _loadDocuments,
            deletingDocumentKeys: _deletingDocumentKeys,
            onDelete: _deleteDocument,
            formatFileSize: _formatFileSize,
          ),
        ],
      ),
    );
  }
}

class _DocumentHistorySection extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<UploadedDocumentListItem> documents;
  final Future<void> Function() onRefresh;
  final Future<void> Function(UploadedDocumentListItem item) onDelete;
  final Set<String> deletingDocumentKeys;
  final String Function(int bytes) formatFileSize;

  const _DocumentHistorySection({
    required this.isLoading,
    required this.error,
    required this.documents,
    required this.onRefresh,
    required this.onDelete,
    required this.deletingDocumentKeys,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previously Uploaded Files',
                      style: TextStyle(
                        color: Color(0xFF020817),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Files listed from Cloudflare R2 with their current ingestion status.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            _HistoryMessage(
              icon: Icons.error_outline,
              color: const Color(0xFFB91C1C),
              title: 'Could not load uploaded files',
              subtitle: error!,
            )
          else if (documents.isEmpty)
            const _HistoryMessage(
              icon: Icons.folder_open,
              color: Color(0xFF64748B),
              title: 'No uploaded files yet',
              subtitle: 'Once you upload documents, they will appear here.',
            )
          else
            Column(
              children: [
                for (final document in documents) ...[
                  _HistoryRow(
                    item: document,
                    isDeleting: deletingDocumentKeys.contains(
                      document.documentId?.isNotEmpty == true
                          ? document.documentId!
                          : document.key,
                    ),
                    onDelete: () => onDelete(document),
                    formatFileSize: formatFileSize,
                  ),
                  if (document != documents.last)
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _HistoryMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final UploadedDocumentListItem item;
  final bool isDeleting;
  final VoidCallback onDelete;
  final String Function(int bytes) formatFileSize;

  const _HistoryRow({
    required this.item,
    required this.isDeleting,
    required this.onDelete,
    required this.formatFileSize,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF059669);
      case 'parsed':
      case 'classified':
      case 'chunked':
      case 'embedded':
        return const Color(0xFF2563EB);
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ');
  }

  String? _extractionLabel() {
    if (item.status == 'failed') {
      return null;
    }

    final extractionMethod = item.extractionMethod;
    if (extractionMethod == null || extractionMethod.isEmpty) {
      if (item.ocrRequired != null) {
        return item.ocrRequired! ? 'OCR used' : 'Text parsed';
      }
      return null;
    }

    switch (extractionMethod) {
      case 'document_ai_expense':
        return 'AI expense parser';
      case 'document_ai_invoice':
        return 'AI invoice parser';
      case 'document_ai_bank_statement':
        return 'AI bank statement parser';
      case 'document_ai_ocr':
        return 'AI OCR parser';
      case 'pdf_text':
        return 'PDF text parsed';
      case 'ocr_image':
        return 'Image OCR used';
      case 'ocr_scanned_pdf':
        return 'Scanned PDF OCR used';
      default:
        return extractionMethod.replaceAll('_', ' ');
    }
  }

  String? _failureReason() {
    final notes = item.parsingNotes?.trim();
    if (notes == null || notes.isEmpty) return null;
    return notes;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    final lastModified = item.lastModified;
    final failureReason = _failureReason();
    final extractionLabel = _extractionLabel();
    final chunkPreview = item.chunkPreview?.trim();
    final subtitleParts = item.status == 'failed'
        ? <String>[
            formatFileSize(item.size),
            if (item.mimeType != null) item.mimeType!,
            if (failureReason != null) failureReason,
            if (lastModified != null)
              '${lastModified.day.toString().padLeft(2, '0')}/${lastModified.month.toString().padLeft(2, '0')}/${lastModified.year}',
          ]
        : <String>[
            formatFileSize(item.size),
            if (item.mimeType != null) item.mimeType!,
            if (item.totalPages != null)
              '${item.totalPages} page${item.totalPages == 1 ? '' : 's'}',
            if (extractionLabel != null) extractionLabel,
            if (lastModified != null)
              '${lastModified.day.toString().padLeft(2, '0')}/${lastModified.month.toString().padLeft(2, '0')}/${lastModified.year}',
          ];

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.mimeType == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.fileName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' . '),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(item.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              onPressed: isDeleting ? null : onDelete,
              tooltip: 'Delete file',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              icon: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                    ),
            ),
          ],
        ),
      ],
    );

    if (item.status == 'completed' &&
        chunkPreview != null &&
        chunkPreview.isNotEmpty) {
      return Tooltip(
        message: chunkPreview,
        waitDuration: const Duration(milliseconds: 250),
        showDuration: const Duration(seconds: 8),
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
        ),
        child: rowContent,
      );
    }

    return rowContent;
  }
}

class _FormatChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color background;
  final Color border;

  const _FormatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 20 : 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onBrowse;

  const _DropZone({
    required this.isUploading,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFC7D3E6),
        radius: 18,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 448),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3F8),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  isUploading ? Icons.cloud_upload_outlined : Icons.upload_rounded,
                  size: 42,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                isUploading ? 'Uploading your document' : 'Drag & drop your documents',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF020817),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isUploading
                    ? 'Your file is being saved and registered for ingestion.'
                    : 'or click to browse . PDF, JPG, PNG up to 15MB',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 34),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _PrimaryUploadButton(
                    label: isUploading ? 'Uploading...' : 'Browse Files',
                    onPressed: isUploading ? null : onBrowse,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color leadingColor;
  final Widget trailing;

  const _UploadStatusCard({
    required this.title,
    required this.subtitle,
    required this.leadingColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: leadingColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: leadingColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _PrimaryUploadButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryUploadButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF2563EB),
          disabledBackgroundColor: const Color(0xFF93C5FD),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 6.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}