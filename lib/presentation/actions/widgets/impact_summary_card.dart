// lib/presentation/actions/widgets/impact_summary_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recommendation_model.dart';

class ImpactSummaryCard extends StatelessWidget {
  final RecommendationSummary    summary;
  final List<Recommendation>     recommendations;

  const ImpactSummaryCard({
    super.key,
    required this.summary,
    required this.recommendations,
  });

  String _rmFormat(double amount) {
    return 'RM ${NumberFormat('#,###', 'en_MY').format(amount.round())}';
  }

  Color _barColor(String impactType) {
    switch (impactType) {
      case 'Cash Inflow':         return const Color(0xFF10B981);
      case 'Cash Buffer':         return const Color(0xFFF59E0B);
      case 'Cost Savings':        return const Color(0xFF60A5FA);
      case 'Available Financing': return const Color(0xFF8B5CF6);
      default:                    return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bar chart uses projected_impact_value; exclude financing from denominator
    final nonFinancing = recommendations
        .where((r) => r.impactType != 'Available Financing')
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final maxValue = nonFinancing.isEmpty
        ? 1.0
        : nonFinancing.first.projectedImpactValue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: trophy + total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL ACTIONABLE FINANCIAL IMPACT',
                      style: TextStyle(
                        color:       Colors.white54,
                        fontSize:    11,
                        fontWeight:  FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width:  42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:  Colors.white.withOpacity(0.1),
                            shape:  BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_outlined,
                            color: Color(0xFFFBBF24),
                            size:  22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '+${_rmFormat(summary.totalActionableImpact)}',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Across ${nonFinancing.length} non-financing recommendations'
                      ' · Excludes SME loan (up to RM 50,000)',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right: breakdown pills
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (summary.cashInflow > 0)
                    _buildPill(
                      '+${_rmFormat(summary.cashInflow)}',
                      'Invoice Collections',
                      const Color(0xFF10B981),
                    ),
                  if (summary.cashBuffer > 0) ...[
                    const SizedBox(height: 8),
                    _buildPill(
                      '+${_rmFormat(summary.cashBuffer)}',
                      'Cash Buffer',
                      const Color(0xFFF59E0B),
                    ),
                  ],
                  if (summary.costSavings > 0) ...[
                    const SizedBox(height: 8),
                    _buildPill(
                      '+${_rmFormat(summary.costSavings)}',
                      'Cost Savings',
                      const Color(0xFF60A5FA),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bar chart (non-financing recs, sorted by rank) ────────────────
          ...nonFinancing.asMap().entries.map((entry) {
            final idx      = entry.key;
            final rec      = entry.value;
            final fraction = maxValue > 0
                ? (rec.projectedImpactValue / maxValue).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${idx + 1}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color:        Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color:        _barColor(rec.impactType),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _rmFormat(rec.projectedImpactValue),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPill(String amount, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(amount,
              style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.bold,
                  fontSize:   13)),
          Text(label,
              style: TextStyle(
                  color:    color.withOpacity(0.8),
                  fontSize: 10)),
        ],
      ),
    );
  }
}