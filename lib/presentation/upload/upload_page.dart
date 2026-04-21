import 'package:flutter/material.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  static const Color _ink = Color(0xFF020817);
  static const Color _surface = Color(0xFFF8FAFC);

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will connect to document ingestion next.')),
    );
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
            onBrowse: () => _showComingSoon(context, 'Browse Files'),
            onDemo: () => _showComingSoon(context, 'Try Demo Upload'),
          ),
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
  final VoidCallback onBrowse;
  final VoidCallback onDemo;

  const _DropZone({
    required this.onBrowse,
    required this.onDemo,
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
                child: const Icon(
                  Icons.upload_rounded,
                  size: 42,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Drag & drop your documents',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF020817),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'or click to browse . PDF, JPG, PNG up to 10MB',
                textAlign: TextAlign.center,
                style: TextStyle(
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
                    label: 'Browse Files',
                    onPressed: onBrowse,
                  ),
                  _DemoUploadButton(
                    label: 'Try Demo Upload',
                    onPressed: onDemo,
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

class _PrimaryUploadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

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
          foregroundColor: Colors.white,
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

class _DemoUploadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DemoUploadButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.bolt_outlined,
          color: Color(0xFFF59E0B),
          size: 22,
        ),
        label: Text(label),
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFEFF3F8),
          foregroundColor: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
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
