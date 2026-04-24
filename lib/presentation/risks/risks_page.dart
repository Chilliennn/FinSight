import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/* ====================================================================== *
 *                             DATA MODELS                                *
 * ====================================================================== */

enum RiskSeverity { critical, high, medium, low }

RiskSeverity _severityFromString(String s) {
  switch (s.toLowerCase()) {
    case 'critical':
      return RiskSeverity.critical;
    case 'high':
      return RiskSeverity.high;
    case 'medium':
      return RiskSeverity.medium;
    default:
      return RiskSeverity.low;
  }
}

String _severityLabel(RiskSeverity s) {
  switch (s) {
    case RiskSeverity.critical:
      return 'CRITICAL';
    case RiskSeverity.high:
      return 'HIGH';
    case RiskSeverity.medium:
      return 'MEDIUM';
    case RiskSeverity.low:
      return 'LOW';
  }
}

class RiskAlert {
  final String id;
  final String type;
  final String category;
  final RiskSeverity severity;
  final String title;
  final String description;
  final String? detailedExplanation;
  final double affectedAmount;
  final String? timeframe;

  const RiskAlert({
    required this.id,
    required this.type,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.detailedExplanation,
    required this.affectedAmount,
    this.timeframe,
  });

  factory RiskAlert.fromJson(Map<String, dynamic> json) => RiskAlert(
    id: json['_id'] as String,
    type: json['type'] as String,
    category: (json['category'] ?? '') as String,
    severity: _severityFromString(json['severity'] as String),
    title: json['title'] as String,
    description: (json['description'] ?? '') as String,
    detailedExplanation: json['detailed_explanation'] as String?,
    affectedAmount: (json['affected_amount'] as num).toDouble(),
    timeframe: json['timeframe'] as String?,
  );
}

class SeverityCounts {
  final int critical, high, medium, low;

  const SeverityCounts({
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
  });

  factory SeverityCounts.fromJson(Map<String, dynamic> j) => SeverityCounts(
    critical: (j['critical'] ?? 0) as int,
    high: (j['high'] ?? 0) as int,
    medium: (j['medium'] ?? 0) as int,
    low: (j['low'] ?? 0) as int,
  );
}

class RiskScore {
  final double score;
  final String label;
  final int percent;

  const RiskScore({
    required this.score,
    required this.label,
    required this.percent,
  });

  factory RiskScore.fromJson(Map<String, dynamic> j) => RiskScore(
    score: (j['score'] as num).toDouble(),
    label: j['label'] as String,
    percent: (j['percent'] as num).toInt(),
  );
}

class RiskDashboardData {
  final String businessName;
  final List<RiskAlert> risks;
  final SeverityCounts counts;
  final RiskScore score;
  final DateTime? lastUpdated;

  const RiskDashboardData({
    required this.businessName,
    required this.risks,
    required this.counts,
    required this.score,
    this.lastUpdated,
  });

  factory RiskDashboardData.fromJson(Map<String, dynamic> j) {
    final business = (j['business'] as Map<String, dynamic>?) ?? const {};
    return RiskDashboardData(
      businessName: (business['name'] ?? 'Business') as String,
      risks: (j['risks'] as List)
          .map((e) => RiskAlert.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: SeverityCounts.fromJson(j['counts'] as Map<String, dynamic>),
      score: RiskScore.fromJson(j['score'] as Map<String, dynamic>),
      lastUpdated: j['last_updated'] != null
          ? DateTime.parse(j['last_updated'] as String)
          : null,
    );
  }

  List<RiskAlert> bySeverity(RiskSeverity s) =>
      risks.where((r) => r.severity == s).toList();
}

/// Optional summary passed in from xy's Recommendations feature.
/// When null, the bottom CTA is hidden.
class RecommendationsSummary {
  final int count;
  final double totalImpact;
  final VoidCallback onViewRecommendations;

  const RecommendationsSummary({
    required this.count,
    required this.totalImpact,
    required this.onViewRecommendations,
  });
}

/* ====================================================================== *
 *                              API CLIENT                                *
 * ====================================================================== */

/// Abstract contract — makes it easy to swap real backend vs demo data.
abstract class RisksApi {
  Future<RiskDashboardData> fetch(String businessId);
  Future<RiskDashboardData> detect(String businessId);

  /// Real backend. Use when your Node.js server is running.
  factory RisksApi.http({required String baseUrl, http.Client? client}) =>
      _HttpRisksApi(baseUrl: baseUrl, client: client);

  /// Demo mode — returns Maju Bakery scenario instantly, no backend needed.
  /// Use this to preview the UI before backend is wired up.
  factory RisksApi.demo() = _DemoRisksApi;
}

class _HttpRisksApi implements RisksApi {
  final String baseUrl;
  final http.Client _client;

  _HttpRisksApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<RiskDashboardData> fetch(String businessId) async {
    final res = await _client.get(Uri.parse('$baseUrl/api/risks/$businessId'));
    return _parse(res);
  }

  @override
  Future<RiskDashboardData> detect(String businessId) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/risks/$businessId/detect'),
    );
    return _parse(res);
  }

  RiskDashboardData _parse(http.Response res) {
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error'] ?? 'Unknown error');
    }
    return RiskDashboardData.fromJson(body['data'] as Map<String, dynamic>);
  }
}

/// Demo data matching the Figma mockup exactly.
/// When backend is ready, swap `RisksApi.demo()` → `RisksApi.http(baseUrl: ...)`.
class _DemoRisksApi implements RisksApi {
  @override
  Future<RiskDashboardData> fetch(String businessId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockData();
  }

  @override
  Future<RiskDashboardData> detect(String businessId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockData();
  }

  RiskDashboardData _mockData() {
    return RiskDashboardData(
      businessName: 'Maju Bakery & Cafe Sdn Bhd',
      risks: [
        RiskAlert(
          id: 'r1',
          type: 'cash_flow_gap',
          category: 'Cash Flow',
          severity: RiskSeverity.critical,
          title: 'Cash Flow Gap in 6 Weeks',
          description:
              'Projected cash balance will reach -RM 2,550 by 26 May 2026',
          detailedExplanation:
              'At the current spending pace, your cash balance will turn negative by approximately RM 2,550 in week 6. If not addressed, you will be unable to cover operating expenses and may face payment defaults.',
          affectedAmount: 2550,
          timeframe: 'Week 6 from now',
        ),
        RiskAlert(
          id: 'r2',
          type: 'overdue_invoices',
          category: 'Receivables',
          severity: RiskSeverity.high,
          title: '3 Overdue Invoices Unpaid',
          description:
              'RM 18,200 outstanding across 3 invoices (oldest: 39 days overdue)',
          detailedExplanation:
              'You have 3 invoices totalling RM 18,200 that are past their due date (oldest is 39 days overdue). Every extra day of delay increases collection risk and ties up working capital.',
          affectedAmount: 18200,
          timeframe: 'Now',
        ),
        RiskAlert(
          id: 'r3',
          type: 'expense_spike',
          category: 'Expenses',
          severity: RiskSeverity.high,
          title: 'Operating Expenses Up 28% vs Last Month',
          description: 'April expenses on pace to exceed March by RM 6,800',
          detailedExplanation:
              'Your expenses this month are on pace to reach RM 30,600, 28% higher than last month\'s RM 23,800. If the trend continues, profit margins will compress significantly.',
          affectedAmount: 6800,
          timeframe: 'This month',
        ),
        RiskAlert(
          id: 'r4',
          type: 'revenue_decline',
          category: 'Revenue',
          severity: RiskSeverity.medium,
          title: 'Revenue Declining 3 Consecutive Months',
          description:
              'Monthly revenue dropped from RM 50,300 (Jan) to RM 42,800 (Apr projected)',
          detailedExplanation:
              'Monthly revenue has fallen for 3 consecutive months, from RM 50,300 to RM 42,800. Sustained decline will erode your cash buffer and limit reinvestment capacity.',
          affectedAmount: 7500,
          timeframe: 'Last 3 months',
        ),
        RiskAlert(
          id: 'r5',
          type: 'large_payable',
          category: 'Payables',
          severity: RiskSeverity.medium,
          title: 'Large Supplier Payment Due in 6 Weeks',
          description:
              'Annual agreement renewal payment of RM 12,000 to Sunrise Ingredients',
          detailedExplanation:
              'A payment of RM 12,000 to Sunrise Ingredients is due in 6 weeks — a large share of your current cash balance of RM 28,450. Failing to plan for it could trigger a short-term cash squeeze.',
          affectedAmount: 12000,
          timeframe: 'Week 6 from now',
        ),
      ],
      counts: const SeverityCounts(critical: 1, high: 2, medium: 2, low: 0),
      score: const RiskScore(score: 7.4, label: 'HIGH RISK', percent: 74),
      lastUpdated: DateTime(2026, 4, 16),
    );
  }
}

/* ====================================================================== *
 *                              MAIN PAGE                                 *
 * ====================================================================== */

class RisksPage extends StatefulWidget {
  final String businessId;
  final RisksApi api;
  final RecommendationsSummary? recommendations;

  const RisksPage({
    super.key,
    required this.businessId,
    required this.api,
    this.recommendations,
  });

  @override
  State<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends State<RisksPage> {
  late Future<RiskDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetch(widget.businessId);
  }

  Future<void> _reDetect() async {
    setState(() {
      _future = widget.api.detect(widget.businessId);
    });
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtRM(double v) {
    final i = v.round();
    final s = i.toString();
    final buf = StringBuffer();
    for (int idx = 0; idx < s.length; idx++) {
      if (idx > 0 && (s.length - idx) % 3 == 0) buf.write(',');
      buf.write(s[idx]);
    }
    return 'RM ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RiskDashboardData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorState(snap.error.toString());
        }

        final data = snap.data!;
        final triggeredOn = data.lastUpdated ?? DateTime.now();

        return RefreshIndicator(
          onRefresh: _reDetect,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk Alerts',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI-detected financial risks based on transaction analysis and cash flow patterns',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                _summaryCards(data.counts),
                const SizedBox(height: 18),
                _scoreBanner(data.score, triggeredOn),
                const SizedBox(height: 24),
                ..._sections(data),
                if (widget.recommendations != null) ...[
                  const SizedBox(height: 16),
                  _recommendationsCta(widget.recommendations!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /* ----------------------- SUMMARY CARDS (4) --------------------- */

  Widget _summaryCards(SeverityCounts c) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            c.critical,
            'Critical',
            'Immediate action needed',
            const Color(0xFFEF4444),
            const Color(0xFFFEF2F2),
            const Color(0xFFFECACA),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            c.high,
            'High',
            'Action within 7 days',
            const Color(0xFFF59E0B),
            const Color(0xFFFFFBEB),
            const Color(0xFFFDE68A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            c.medium,
            'Medium',
            'Monitor closely',
            const Color(0xFFEAB308),
            const Color(0xFFFEFCE8),
            const Color(0xFFFEF08A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            c.low,
            'Low',
            'Informational',
            const Color(0xFF94A3B8),
            const Color(0xFFF8FAFC),
            const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    int count,
    String label,
    String subtitle,
    Color color,
    Color bg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /* ------------------------ SCORE BANNER ------------------------ */

  Widget _scoreBanner(RiskScore score, DateTime triggeredOn) {
    final isHigh = score.label == 'HIGH RISK';
    final isMed = score.label == 'MEDIUM RISK';
    final bg = isHigh
        ? const Color(0xFFEF4444)
        : isMed
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final bgDark = isHigh
        ? const Color(0xFFB91C1C)
        : isMed
        ? const Color(0xFFB45309)
        : const Color(0xFF047857);

    final nextReview = triggeredOn.add(const Duration(days: 7));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [bg, bgDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERALL FINANCIAL RISK SCORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          score.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '/10',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              score.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Triggered On',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtDate(triggeredOn),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Next review: ${_fmtDate(nextReview)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Risk Level',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${score.percent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score.percent / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------- GROUPED ALERT SECTIONS ------------------- */

  List<Widget> _sections(RiskDashboardData data) {
    final groups = [
      (
        list: data.bySeverity(RiskSeverity.critical),
        label: 'CRITICAL RISKS — IMMEDIATE ACTION REQUIRED',
        color: const Color(0xFFEF4444),
      ),
      (
        list: data.bySeverity(RiskSeverity.high),
        label: 'HIGH SEVERITY — ACTION WITHIN 7 DAYS',
        color: const Color(0xFFF59E0B),
      ),
      (
        list: data.bySeverity(RiskSeverity.medium),
        label: 'MEDIUM SEVERITY — MONITOR CLOSELY',
        color: const Color(0xFFEAB308),
      ),
      (
        list: data.bySeverity(RiskSeverity.low),
        label: 'LOW — INFORMATIONAL',
        color: const Color(0xFF94A3B8),
      ),
    ];

    final out = <Widget>[];
    for (final g in groups) {
      if (g.list.isEmpty) continue;
      out.add(_sectionHeader(g.label, g.color));
      for (final r in g.list) {
        out.add(const SizedBox(height: 10));
        out.add(_RiskCard(alert: r, fmtRM: _fmtRM));
      }
      out.add(const SizedBox(height: 20));
    }

    if (out.isEmpty) out.add(_emptyState());
    return out;
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          _Dot(color: color, size: 10),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------ CTA + STATES ----------------------- */

  Widget _recommendationsCta(RecommendationsSummary r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to resolve these risks?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FinSight AI has generated ${r.count} ranked recommendations with specific '
                  'actions and quantified impact. Following the top 3 alone can prevent the '
                  'cash flow gap and recover ${_fmtRM(r.totalImpact)}.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: r.onViewRecommendations,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('View Recommendations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          const Text(
            'No active risks detected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your financials are in good shape.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _reDetect,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Run detection again'),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load risks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _future = widget.api.fetch(widget.businessId);
              }),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================================================================== *
 *               SMALL PRIVATE HELPERS (kept minimal)                     *
 * ====================================================================== */

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// One expandable alert card. Kept as a StatefulWidget because the
/// "View detailed explanation" needs local toggle state.
class _RiskCard extends StatefulWidget {
  final RiskAlert alert;
  final String Function(double) fmtRM;

  const _RiskCard({required this.alert, required this.fmtRM});

  @override
  State<_RiskCard> createState() => _RiskCardState();
}

class _RiskCardState extends State<_RiskCard> {
  bool _expanded = false;

  ({Color accent, Color bg, Color border}) _style(RiskSeverity s) {
    switch (s) {
      case RiskSeverity.critical:
        return (
          accent: const Color(0xFFEF4444),
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
        );
      case RiskSeverity.high:
        return (
          accent: const Color(0xFFF59E0B),
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
        );
      case RiskSeverity.medium:
        return (
          accent: const Color(0xFFEAB308),
          bg: const Color(0xFFFEFCE8),
          border: const Color(0xFFFEF08A),
        );
      case RiskSeverity.low:
        return (
          accent: const Color(0xFF64748B),
          bg: const Color(0xFFF8FAFC),
          border: const Color(0xFFE2E8F0),
        );
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'cash_flow_gap':
        return Icons.warning_amber_rounded;
      case 'overdue_invoices':
        return Icons.description_outlined;
      case 'expense_spike':
        return Icons.trending_down_rounded;
      case 'revenue_decline':
        return Icons.bar_chart_rounded;
      case 'large_payable':
        return Icons.calendar_today_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final st = _style(a.severity);

    return Container(
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: st.border, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: st.border),
                  ),
                  child: Icon(_icon(a.type), color: st.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Severity pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: st.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _severityLabel(a.severity),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          if (a.category.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _chip(a.category),
                          ],
                          if (a.timeframe != null &&
                              a.timeframe!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _chip(a.timeframe!, withClock: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.fmtRM(a.affectedAmount),
                      style: TextStyle(
                        color: st.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'affected',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: st.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'View detailed explanation',
                      style: TextStyle(
                        color: st.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: st.border),
                  ),
                  child: Text(
                    a.detailedExplanation ??
                        'No detailed explanation available.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool withClock = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withClock) ...[
            const Icon(
              Icons.schedule_rounded,
              size: 12,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* ====================================================================== *
 *          SIDEBAR BADGE — for app_layout.dart to embed                  *
 *                                                                        *
 *   Shows:  "X Active Risks" + "Last updated: dd MMM yyyy"               *
 *   Source: Real backend via GET /api/risks/:businessId                  *
 *   Refresh: polls every 15s so detect results appear automatically      *
 * ====================================================================== */

class RiskAlertsSidebarBadge extends StatefulWidget {
  final String businessId;
  final RisksApi api;

  const RiskAlertsSidebarBadge({
    super.key,
    required this.businessId,
    required this.api,
  });

  @override
  State<RiskAlertsSidebarBadge> createState() => _RiskAlertsSidebarBadgeState();
}

class _RiskAlertsSidebarBadgeState extends State<RiskAlertsSidebarBadge> {
  RiskDashboardData? _data;
  bool _loading = true;
  Object? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.fetch(widget.businessId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Active = critical + high (matches UI's "Active Risks" definition)
    final activeCount = _data == null
        ? 0
        : _data!.counts.critical + _data!.counts.high;

    final lastUpdated = _data?.lastUpdated;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33F59E0B), // faint amber bg
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66F59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const Text(
                    'Loading risks…',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (_error != null)
                  const Text(
                    'Risks unavailable',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    '$activeCount Active Risk${activeCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  lastUpdated != null
                      ? 'Last updated: ${_fmtDate(lastUpdated)}'
                      : 'Never detected',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
