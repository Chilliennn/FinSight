// lib/presentation/actions/widgets/recommendation_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recommendation_model.dart';

class RecommendationCard extends StatefulWidget {
  final Recommendation recommendation;
  final bool           isHighlighted;   // true = first/priority card
  final VoidCallback   onMarkActioned;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.isHighlighted,
    required this.onMarkActioned,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double>   _expandAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isHighlighted; // priority card starts expanded
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 260),
      value:    widget.isHighlighted ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animController.forward() : _animController.reverse();
  }

  // ── Colour helpers ────────────────────────────────────────────────────────

  String _rmFormat(double amount) =>
      '+RM ${NumberFormat('#,###', 'en_MY').format(amount.round())}';

  Color _categoryColor(String c) {
    switch (c) {
      case 'Collections':         return const Color(0xFF10B981);
      case 'Supplier Management': return const Color(0xFF6366F1);
      case 'Cost Optimization':   return const Color(0xFFEC4899);
      case 'Financing':           return const Color(0xFF8B5CF6);
      default:                    return const Color(0xFF64748B);
    }
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'Easy Action':   return const Color(0xFF10B981);
      case 'Medium Action': return const Color(0xFFF59E0B);
      case 'Hard Action':   return const Color(0xFFEF4444);
      default:              return const Color(0xFF64748B);
    }
  }

  Color _impactColor(String t) {
    switch (t) {
      case 'Cash Inflow':         return const Color(0xFF10B981);
      case 'Cash Buffer':         return const Color(0xFFF59E0B);
      case 'Cost Savings':        return const Color(0xFF3B82F6);
      case 'Available Financing': return const Color(0xFF8B5CF6);
      default:                    return const Color(0xFF64748B);
    }
  }

  IconData _impactIcon(String t) {
    switch (t) {
      case 'Cash Inflow':         return Icons.trending_up;
      case 'Cash Buffer':         return Icons.attach_money;
      case 'Cost Savings':        return Icons.savings_outlined;
      case 'Available Financing': return Icons.account_balance_outlined;
      default:                    return Icons.monetization_on_outlined;
    }
  }

  Color _rankBg(int rank) {
    switch (rank) {
      case 1:  return const Color(0xFF2563EB);
      case 2:  return const Color(0xFF0F172A);
      case 3:  return const Color(0xFFF59E0B);
      default: return const Color(0xFFE2E8F0);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rec         = widget.recommendation;
    final isActioned  = rec.isActioned;
    final impactColor = _impactColor(rec.impactType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isHighlighted
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.circular(12),
        border: Border.all(
          color: isActioned
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank badge
                Container(
                  width:  40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _rankBg(rec.rank),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${rec.rank}',
                      style: TextStyle(
                        color:      rec.rank <= 3 ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize:   13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title / tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing:    6,
                        runSpacing: 4,
                        children: [
                          _tag(rec.category,   _categoryColor(rec.category)),
                          _tag(rec.difficulty,  _difficultyColor(rec.difficulty), outlined: true),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(rec.timeframe,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // action_title — main card heading
                      Text(
                        rec.actionTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   15,
                            color:      Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      // action_plan — subtitle line
                      Text(
                        rec.actionPlan,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Impact pill — uses projected_impact_value
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:  impactColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: impactColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rec.impactType == 'Available Financing'
                            ? 'Up to RM 50,000'
                            : _rmFormat(rec.projectedImpactValue),
                        style: TextStyle(
                          color:      impactColor,
                          fontWeight: FontWeight.bold,
                          fontSize:   15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_impactIcon(rec.impactType),
                              size: 11, color: impactColor),
                          const SizedBox(width: 3),
                          Text(rec.impactType,
                              style: TextStyle(
                                  color:      impactColor,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Toggle row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggle,
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns:    _expanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.expand_less,
                            size: 18, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _expanded ? 'Hide details' : 'View reasoning & steps',
                        style: const TextStyle(
                          color:      Color(0xFF2563EB),
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isActioned)
                  Row(children: const [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 4),
                    Text('Actioned',
                        style: TextStyle(
                            color:      Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize:   13)),
                  ])
                else
                  ElevatedButton.icon(
                    onPressed: widget.onMarkActioned,
                    icon:  const Icon(Icons.flash_on, size: 14),
                    label: const Text('Mark as Actioned',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ),

          // ── Expandable details ────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // AI Reasoning — uses rec.reasoning (DB field: reasoning)
                  _sectionHeader(Icons.radar, 'AI Reasoning'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      rec.reasoning,
                      style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 13,
                          height:   1.6),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Steps
                  _sectionHeader(Icons.check_circle_outline, 'Action Steps'),
                  const SizedBox(height: 10),
                  ...rec.actionSteps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width:  24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${step.stepNumber}',
                              style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(step.description,
                                style: const TextStyle(
                                    color:    Color(0xFF374151),
                                    fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  )),

                  // Related reference (e.g. invoice number)
                  if (rec.relatedReference != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFD97706), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Related reference: ${rec.relatedReference}',
                            style: const TextStyle(
                              color:      Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              fontSize:   12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   14,
                color:      Color(0xFF0F172A))),
      ],
    );
  }

  Widget _tag(String label, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        outlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(
          color: outlined ? color.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Text(label,
          style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600)),
    );
  }
}