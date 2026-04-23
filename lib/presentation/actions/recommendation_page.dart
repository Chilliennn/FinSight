// lib/presentation/actions/recommendation_page.dart
//
// Behaviour:
//   1. On open → fetchRecommendations() reads existing recs from recommendations collection.
//      If recs exist they display immediately — no Z.AI call on load.
//   2. "Generate with AI" button → generateFromTransactions() triggers server-side
//      transaction analysis → Z.AI → stores fresh recs → re-renders.
//   3. "Mark as Actioned" → markActioned() updates status in DB.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'recommendation_model.dart';
import 'recommendation_repository.dart';


class RecommendationPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String businessType;
  final String riskId;
  final double currentBalance;

  const RecommendationPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessType,
    required this.riskId,
    required this.currentBalance,
  });

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final RecommendationRepository _repo = RecommendationRepository();

  List<Recommendation>   _recs    = [];
  RecommendationSummary? _summary;
  bool    _loadingRecs  = true;   // initial fetch
  bool    _generating   = false;  // Z.AI generation in progress
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();  // always try DB first
  }

  // ── Step 1: fetch existing recs from recommendations collection ──────────
  Future<void> _loadExisting() async {
    setState(() { _loadingRecs = true; _error = null; });
    try {
      final result = await _repo.fetchRecommendations(widget.businessId);
      setState(() {
        _summary      = result['summary']         as RecommendationSummary;
        _recs         = result['recommendations'] as List<Recommendation>;
        _loadingRecs  = false;
      });
    } catch (err) {
      setState(() { _error = err.toString(); _loadingRecs = false; });
    }
  }

  // ── Step 2 (on demand): generate fresh recs via Z.AI from transactions ───
  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });
    try {
      final result = await _repo.generateFromTransactions(
        businessId:     widget.businessId,
        riskId:         widget.riskId,
        businessName:   widget.businessName,
        businessType:   widget.businessType,
        currentBalance: widget.currentBalance,
      );
      setState(() {
        _summary    = result['summary']         as RecommendationSummary;
        _recs       = result['recommendations'] as List<Recommendation>;
        _generating = false;
      });
    } catch (err) {
      setState(() { _error = err.toString(); _generating = false; });
    }
  }

  // ── Mark actioned ────────────────────────────────────────────────────────
  Future<void> _markActioned(String id) async {
    try {
      final updated = await _repo.markActioned(id);
      setState(() {
        _recs = _recs.map((r) => r.id == id ? updated : r).toList();
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('Failed to update: $err'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loadingRecs) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildContent();
  }

  Widget _buildContent() {
    final Recommendation? topRec =
        _recs.isNotEmpty && !_recs.first.isActioned ? _recs.first : null;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [

        // ── Header ──────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Decision Recommendations',
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recs.isEmpty
                        ? 'No recommendations yet. Tap "Generate with AI" to analyse your transactions.'
                        : '${_summary?.totalRecommendations ?? 0} ranked actions from your transaction data.',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(_generating ? 'Generating…' : 'Generate with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Error banner ────────────────────────────────────────────────────
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
              TextButton(
                onPressed: _generate,
                child: const Text('Retry'),
              ),
            ]),
          ),

        // ── Empty state ─────────────────────────────────────────────────────
        if (_recs.isEmpty && _error == null && !_generating)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No recommendations yet',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Generate with AI" above to analyse\nyour transaction data and get ranked actions.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // ── Impact summary card ─────────────────────────────────────────────
        if (_recs.isNotEmpty && _summary != null) ...[
          _ImpactSummaryCard(summary: _summary!, recommendations: _recs),
          const SizedBox(height: 16),
          // Stat chips
          Row(children: [
            Expanded(child: _StatChip(
              value:   '${_summary!.easyActions}',
              label:   'Easy Actions',
              color:   const Color(0xFF10B981),
              bgColor: const Color(0xFFF0FDF4),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatChip(
              value:   '${_summary!.totalRecommendations}',
              label:   'Total Actions',
              color:   const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatChip(
              value:   '${_summary!.canActToday}',
              label:   'Act Today',
              color:   const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
            )),
          ]),
          const SizedBox(height: 20),
        ],

        // ── Highest priority banner ─────────────────────────────────────────
        if (topRec != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: const [
              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
              SizedBox(width: 8),
              Text(
                'HIGHEST PRIORITY · RECOMMENDED FIRST ACTION',
                style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 12, letterSpacing: 0.5,
                ),
              ),
            ]),
          ),
          _RecommendationCard(
            rec:           topRec,
            isHighlighted: true,
            onActioned:    () => _markActioned(topRec.id),
          ),
          const SizedBox(height: 16),
        ],

        // ── Remaining cards ─────────────────────────────────────────────────
        ..._recs
            .skip(topRec != null ? 1 : 0)
            .map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecommendationCard(
                rec:           rec,
                isHighlighted: false,
                onActioned:    () => _markActioned(rec.id),
              ),
            )),

        // ── AI disclaimer ───────────────────────────────────────────────────
        if (_recs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These recommendations are generated by FinSight AI from your transaction '
                    'records. Always consult a qualified financial advisor before making '
                    'significant decisions. Impact figures are estimates.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ImpactSummaryCard
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactSummaryCard extends StatelessWidget {
  final RecommendationSummary summary;
  final List<Recommendation>  recommendations;
  const _ImpactSummaryCard({required this.summary, required this.recommendations});

  String _rm(double v) => 'RM ${NumberFormat('#,###', 'en_MY').format(v.round())}';

  Color _barColor(String t) {
    switch (t) {
      case 'Cash Inflow':         return const Color(0xFF10B981);
      case 'Cash Buffer':         return const Color(0xFFF59E0B);
      case 'Cost Savings':        return const Color(0xFF60A5FA);
      case 'Available Financing': return const Color(0xFF8B5CF6);
      default:                    return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nonFin = recommendations
        .where((r) => r.impactType != 'Available Financing')
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final maxVal = nonFin.isEmpty ? 1.0 : nonFin.first.projectedImpactValue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOTAL ACTIONABLE FINANCIAL IMPACT',
                    style: TextStyle(color: Colors.white54, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFFBBF24), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('+${_rm(summary.totalActionableImpact)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Across ${nonFin.length} non-financing recommendations'
                  ' · Excludes SME loan (up to RM 50,000)',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (summary.cashInflow > 0)
                _Pill('+${_rm(summary.cashInflow)}', 'Invoice Collections', const Color(0xFF10B981)),
              if (summary.cashBuffer > 0) ...[
                const SizedBox(height: 8),
                _Pill('+${_rm(summary.cashBuffer)}', 'Cash Buffer', const Color(0xFFF59E0B)),
              ],
              if (summary.costSavings > 0) ...[
                const SizedBox(height: 8),
                _Pill('+${_rm(summary.costSavings)}', 'Cost Savings', const Color(0xFF60A5FA)),
              ],
            ]),
          ]),
          const SizedBox(height: 20),
          ...nonFin.asMap().entries.map((e) {
            final frac = maxVal > 0
                ? (e.value.projectedImpactValue / maxVal).clamp(0.0, 1.0)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 28,
                  child: Text('#${e.key + 1}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(
                  child: Stack(children: [
                    Container(height: 8,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(height: 8,
                          decoration: BoxDecoration(
                              color: _barColor(e.value.impactType),
                              borderRadius: BorderRadius.circular(4))),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(_rm(e.value.projectedImpactValue),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.right),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String amount, label;
  final Color color;
  const _Pill(this.amount, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label,  style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatChip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value, label;
  final Color color, bgColor;
  const _StatChip({
    required this.value, required this.label,
    required this.color, required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecommendationCard
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationCard extends StatefulWidget {
  final Recommendation rec;
  final bool           isHighlighted;
  final VoidCallback   onActioned;
  const _RecommendationCard({
    required this.rec,
    required this.isHighlighted,
    required this.onActioned,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard>
    with SingleTickerProviderStateMixin {
  late bool                _expanded;
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isHighlighted;
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 260),
      value:    widget.isHighlighted ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  String _rm(double v) => '+RM ${NumberFormat('#,###', 'en_MY').format(v.round())}';

  Color _catColor(String c) {
    switch (c) {
      case 'Collections':         return const Color(0xFF10B981);
      case 'Supplier Management': return const Color(0xFF6366F1);
      case 'Cost Optimization':   return const Color(0xFFEC4899);
      case 'Financing':           return const Color(0xFF8B5CF6);
      default:                    return const Color(0xFF64748B);
    }
  }

  Color _diffColor(String d) {
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

  @override
  Widget build(BuildContext context) {
    final rec         = widget.rec;
    final isActioned  = rec.isActioned;
    final impactColor = _impactColor(rec.impactType);
    final rankColors  = {1: const Color(0xFF2563EB), 2: const Color(0xFF0F172A), 3: const Color(0xFFF59E0B)};
    final rankColor   = rankColors[rec.rank] ?? const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isHighlighted
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.circular(12),
        border: Border.all(
          color: isActioned ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Card header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
              child: Center(child: Text('#${rec.rank}',
                  style: TextStyle(
                    color:      rec.rank <= 3 ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Tag(rec.category,  _catColor(rec.category)),
                  _Tag(rec.difficulty, _diffColor(rec.difficulty), outlined: true),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(rec.timeframe,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Text(rec.actionTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(rec.actionPlan,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        impactColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: impactColor.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  rec.impactType == 'Available Financing'
                      ? 'Up to RM 50,000'
                      : _rm(rec.projectedImpactValue),
                  style: TextStyle(
                      color: impactColor, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_impactIcon(rec.impactType), size: 11, color: impactColor),
                  const SizedBox(width: 3),
                  Text(rec.impactType,
                      style: TextStyle(color: impactColor, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
        ),

        // Toggle / action row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(children: [
            GestureDetector(
              onTap: _toggle,
              child: Row(children: [
                AnimatedRotation(
                  turns:    _expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.expand_less, size: 18, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 4),
                Text(_expanded ? 'Hide details' : 'View reasoning & steps',
                    style: const TextStyle(
                        color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            if (isActioned)
              Row(children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 4),
                Text('Actioned',
                    style: TextStyle(color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ])
            else
              ElevatedButton.icon(
                onPressed: widget.onActioned,
                icon:  const Icon(Icons.flash_on, size: 14),
                label: const Text('Mark as Actioned', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
          ]),
        ),

        // Expanded detail
        SizeTransition(
          sizeFactor: _anim,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              _SectionHeader(Icons.radar, 'AI Reasoning'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(rec.reasoning,
                    style: const TextStyle(
                        color: Color(0xFF374151), fontSize: 13, height: 1.6)),
              ),
              const SizedBox(height: 16),
              _SectionHeader(Icons.check_circle_outline, 'Action Steps'),
              const SizedBox(height: 10),
              ...rec.actionSteps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                        color: Color(0xFF2563EB), shape: BoxShape.circle),
                    child: Center(child: Text('${step.stepNumber}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(step.description,
                        style: const TextStyle(color: Color(0xFF374151), fontSize: 13)),
                  )),
                ]),
              )),
              if (rec.relatedReference != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 8),
                    Text('Related reference: ${rec.relatedReference}',
                        style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SectionHeader(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFF64748B), size: 16),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
  ]);
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   outlined;
  const _Tag(this.label, this.color, {this.outlined = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        outlined ? Colors.transparent : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: outlined ? color.withOpacity(0.4) : Colors.transparent),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}