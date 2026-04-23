import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/document_upload_repository.dart';

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
  String? _error;
  UploadedDocumentResult? _uploadedDocument;
  PlatformFile? _selectedFile;

  Future<void> _browseAndUpload() async {
    setState(() {
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.name} uploaded. Ready for extraction next.'),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = err.toString().replaceFirst('Exception: ', '');
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
                label: 'Max 10MB per file',
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
                  ? 'Uploading to Cloudflare R2 for ${widget.businessName}'
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
              title: 'Document uploaded',
              subtitle:
                  '${_uploadedDocument!.fileName} stored successfully with status "${_uploadedDocument!.status}"',
              leadingColor: const Color(0xFF059669),
              trailing: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 22,
              ),
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
        ],
      ),
    );
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
                    : 'or click to browse . PDF, JPG, PNG up to 10MB',
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
