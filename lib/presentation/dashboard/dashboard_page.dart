import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardContent extends StatefulWidget {
  final String businessId;
  final VoidCallback? onGoToRecommendations;
  final VoidCallback? onGoToRisks;
  final VoidCallback? onGoToTransactions;

  const DashboardContent({
    super.key,
    required this.businessId,
    this.onGoToRecommendations,
    this.onGoToRisks,
    this.onGoToTransactions,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  late final http.Client _client;

  DashboardData? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final dashboard = await _fetchDashboard(widget.businessId);
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<DashboardData> _fetchDashboard(String businessId) async {
    final uri = Uri.parse('$_apiBaseUrl/api/dashboard/$businessId');
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    final bodyText = response.body.trim();
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();

    if (!contentType.contains('application/json')) {
      final snippet = bodyText.isEmpty
          ? '<empty body>'
          : bodyText.substring(0, math.min(120, bodyText.length));
      throw Exception(
        'Expected JSON from $uri but received ${response.statusCode} '
        '${contentType.isEmpty ? 'with unknown content-type' : 'with $contentType'}. '
        'Body starts with: $snippet',
      );
    }

    final decoded = jsonDecode(bodyText);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON response shape from $uri');
    }

    if (response.statusCode >= 400 || decoded['success'] != true) {
      throw Exception(
        decoded['error']?.toString() ?? 'Server error ${response.statusCode}',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Missing dashboard data payload from $uri');
    }

    return DashboardData.fromJson(data);
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _deltaPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String change,
    required Color changeColor,
    required String value,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Spacer(),
                _deltaPill(change, changeColor),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskTile({
    required String title,
    required String subtitle,
    required Color accent,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: accent.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRm(num value) {
    final rounded = value.round();
    final isNegative = rounded < 0;
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }

    return '${isNegative ? '-' : ''}RM ${buffer.toString()}';
  }

  String _formatSignedRm(num value) {
    final rounded = value.round();
    final prefix = rounded >= 0 ? '+' : '-';
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }

    return '${prefix}RM ${buffer.toString()}';
  }

  Color _changeColor(num value) {
    return value >= 0 ? const Color(0xFF059669) : const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return const SizedBox.shrink();
    }

    final criticalAlert =
        dashboard.alert?.title.contains('Critical Alert') == true
        ? dashboard.alert
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1180;
        final horizontalPadding = constraints.maxWidth < 900 ? 16.0 : 20.0;

        final metricCards = [
          _metricCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF2563EB),
            change: _formatSignedRm(dashboard.kpis.currentBalanceDelta),
            changeColor: _changeColor(dashboard.kpis.currentBalanceDelta),
            value: _formatRm(dashboard.kpis.currentBalance),
            title: 'Current Balance',
            subtitle: 'vs last month',
          ),
          _metricCard(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF10B981),
            change: _formatSignedRm(dashboard.kpis.monthlyRevenueDelta),
            changeColor: _changeColor(dashboard.kpis.monthlyRevenueDelta),
            value: _formatRm(dashboard.kpis.monthlyRevenue),
            title: 'Monthly Revenue',
            subtitle: 'vs last month',
          ),
          _metricCard(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFFF59E0B),
            change: _formatSignedRm(dashboard.kpis.monthlyExpensesDelta),
            changeColor: _changeColor(dashboard.kpis.monthlyExpensesDelta),
            value: _formatRm(dashboard.kpis.monthlyExpenses),
            title: 'Monthly Expenses',
            subtitle: 'vs last month',
          ),
          _metricCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFEF4444),
            change: _formatSignedRm(dashboard.kpis.outstandingInvoices),
            changeColor: const Color(0xFFEF4444),
            value: _formatRm(dashboard.kpis.outstandingInvoices),
            title: 'Outstanding Invoices',
            subtitle:
                '${dashboard.kpis.outstandingInvoicesCount} invoices pending',
          ),
        ];

        final metricGrid = isCompact
            ? Column(
                children: [
                  for (var i = 0; i < metricCards.length; i++) ...[
                    metricCards[i],
                    if (i != metricCards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < metricCards.length; i++) ...[
                    Expanded(child: metricCards[i]),
                    if (i != metricCards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );

        const topCardHeight = 500.0;
        const sideCardWidth = 332.0;
        const bottomCardHeight = 420.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboard.asOfDate.isEmpty
                          ? '16 Apr 2026'
                          : dashboard.asOfDate,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (criticalAlert != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _cardShell(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFFBEB),
                            const Color(0xFFFFF7ED).withOpacity(0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  criticalAlert.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  criticalAlert.subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: widget.onGoToRisks,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('View Risks'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              metricGrid,
              const SizedBox(height: 14),
              if (isCompact) ...[
                _TrendCard(cardShell: _cardShell),
                const SizedBox(height: 14),
                _RecommendationsCard(
                  cardShell: _cardShell,
                  onViewAll: widget.onGoToRecommendations,
                  recommendations: dashboard.recommendations,
                ),
                const SizedBox(height: 14),
                _RiskCard(
                  cardShell: _cardShell,
                  riskTile: _riskTile,
                  onViewAll: widget.onGoToRisks,
                  risks: dashboard.risks,
                  fmtRM: _formatRm,
                ),
                const SizedBox(height: 14),
                _TransactionsCard(
                  cardShell: _cardShell,
                  onViewAll: widget.onGoToTransactions,
                  transactions: dashboard.recentTransactions,
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: topCardHeight,
                        child: _TrendCard(cardShell: _cardShell),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: sideCardWidth,
                      height: topCardHeight,
                      child: _RiskCard(
                        cardShell: _cardShell,
                        riskTile: _riskTile,
                        onViewAll: widget.onGoToRisks,
                        risks: dashboard.risks,
                        fmtRM: _formatRm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: bottomCardHeight,
                        child: _RecommendationsCard(
                          cardShell: _cardShell,
                          onViewAll: widget.onGoToRecommendations,
                          recommendations: dashboard.recommendations,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: sideCardWidth,
                      height: bottomCardHeight,
                      child: _TransactionsCard(
                        cardShell: _cardShell,
                        onViewAll: widget.onGoToTransactions,
                        transactions: dashboard.recentTransactions,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;

  const _TrendCard({required this.cardShell});

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash Balance Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Historical + 8-week forecast',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _LegendDot(color: Color(0xFF3B82F6), label: 'Historical'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFFF59E0B), label: 'Forecast'),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 235, child: _TrendChart()),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Projected negative balance of -RM 2,550 on 26 May 2026',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;
  final Widget Function({
    required String title,
    required String subtitle,
    required Color accent,
    required Color background,
  })
  riskTile;
  final VoidCallback? onViewAll;
  final List<DashboardRiskRow> risks;
  final String Function(num) fmtRM;

  const _RiskCard({
    required this.cardShell,
    required this.riskTile,
    required this.risks,
    required this.fmtRM,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionRow(
              'Risk Alerts',
              '${risks.length} risks detected',
              actionText: 'View all',
              onAction: onViewAll,
            ),
            const SizedBox(height: 12),
            ...risks.take(4).map((risk) {
              final accent = _severityColor(risk.severity);
              final background = _severityBackground(risk.severity);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: riskTile(
                  title: risk.title,
                  subtitle: risk.subtitle.isNotEmpty
                      ? risk.subtitle
                      : '${fmtRM(risk.affectedAmount)} affected',
                  accent: accent,
                  background: background,
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('View All Risks & Details'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFFEAB308);
      case 'low':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _severityBackground(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFF1F2);
      case 'high':
        return const Color(0xFFFFFBEB);
      case 'medium':
        return const Color(0xFFFEFCE8);
      case 'low':
      default:
        return const Color(0xFFF8FAFC);
    }
  }
}

class _RecommendationsCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;
  final VoidCallback? onViewAll;
  final List<DashboardRecommendationRow> recommendations;

  const _RecommendationsCard({
    required this.cardShell,
    required this.recommendations,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionRow(
              'AI Recommendations',
              'Top ranked actions by impact',
              actionText: 'View all ${recommendations.length}',
              onAction: onViewAll,
            ),
            const SizedBox(height: 12),
            ...recommendations.take(3).map((recommendation) {
              final amountColor = _amountColor(recommendation.amountHint);
              final amountText = recommendation.amount.isNotEmpty
                  ? recommendation.amount
                  : _formatSignedRm(recommendation.amountValue);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecommendationRow(
                  index: recommendation.index,
                  title: recommendation.title,
                  subtitle: recommendation.subtitle,
                  amount: amountText,
                  amountHint: recommendation.amountHint,
                  amountColor: amountColor,
                  accent: const Color(0xFF2563EB),
                ),
              );
            }),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Logic: Following recommendations prevents cash flow gaps and increases stability.',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _amountColor(String amountHint) {
    switch (amountHint.toLowerCase()) {
      case 'cash in':
        return const Color(0xFF16A34A);
      case 'buffer':
        return const Color(0xFFF97316);
      case 'save':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatSignedRm(num value) {
    final rounded = value.round();
    final prefix = rounded >= 0 ? '+' : '-';
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }

    return '${prefix}RM ${buffer.toString()}';
  }
}

class _TransactionsCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;
  final VoidCallback? onViewAll;
  final List<DashboardTransactionRow> transactions;

  const _TransactionsCard({
    required this.cardShell,
    required this.transactions,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionRow(
              'Recent Transactions',
              '${transactions.length} total extracted',
              actionText: 'All',
              onAction: onViewAll,
            ),
            const SizedBox(height: 12),
            ...transactions.map(
              (transaction) => _TransactionRow(
                title: transaction.title,
                date: transaction.date,
                amount: transaction.amount.isNotEmpty
                    ? transaction.amount
                    : _formatSignedRm(transaction.amountValue),
                amountColor: transaction.amountValue >= 0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4444),
                icon: transaction.amountValue >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                iconColor: transaction.amountValue >= 0
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSignedRm(num value) {
    final rounded = value.round();
    final prefix = rounded >= 0 ? '+' : '-';
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }

    return '${prefix}RM ${buffer.toString()}';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendChartPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    final paintHistorical = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paintHistoricalFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.18),
          const Color(0xFF3B82F6).withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final paintForecast = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final paintZero = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5;

    const left = 48.0;
    const right = 14.0;
    const top = 12.0;
    const bottom = 30.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final origin = Offset(left, top + chartHeight * 0.62);

    for (var i = 0; i < 5; i++) {
      final y = top + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        paintGrid,
      );
    }

    canvas.drawLine(
      Offset(left, origin.dy),
      Offset(size.width - right, origin.dy),
      paintZero,
    );

    final historicalPoints = [
      Offset(left + chartWidth * 0.00, top + chartHeight * 0.34),
      Offset(left + chartWidth * 0.10, top + chartHeight * 0.31),
      Offset(left + chartWidth * 0.20, top + chartHeight * 0.27),
      Offset(left + chartWidth * 0.30, top + chartHeight * 0.29),
      Offset(left + chartWidth * 0.42, top + chartHeight * 0.36),
      Offset(left + chartWidth * 0.52, top + chartHeight * 0.50),
    ];
    final forecastPoints = [
      Offset(left + chartWidth * 0.52, top + chartHeight * 0.50),
      Offset(left + chartWidth * 0.63, top + chartHeight * 0.47),
      Offset(left + chartWidth * 0.74, top + chartHeight * 0.51),
      Offset(left + chartWidth * 0.84, top + chartHeight * 0.60),
      Offset(left + chartWidth * 0.92, top + chartHeight * 0.97),
      Offset(left + chartWidth * 1.00, top + chartHeight * 0.88),
    ];

    final historicalPath = Path()
      ..moveTo(historicalPoints.first.dx, historicalPoints.first.dy);
    for (final point in historicalPoints.skip(1)) {
      historicalPath.lineTo(point.dx, point.dy);
    }

    final areaPath = Path()
      ..addPath(historicalPath, Offset.zero)
      ..lineTo(historicalPoints.last.dx, origin.dy)
      ..lineTo(historicalPoints.first.dx, origin.dy)
      ..close();

    canvas.drawPath(areaPath, paintHistoricalFill);
    canvas.drawPath(historicalPath, paintHistorical);

    for (var i = 0; i < forecastPoints.length - 1; i++) {
      _drawDashedSegment(
        canvas,
        forecastPoints[i],
        forecastPoints[i + 1],
        paintForecast,
        dashLength: 8,
        gapLength: 5,
      );
    }

    final yLabels = [
      ('RM 60k', top),
      ('RM 40k', top + chartHeight * 0.25),
      ('RM 20k', top + chartHeight * 0.50),
      ('RM 0k', top + chartHeight * 0.75),
      ('RM -20k', top + chartHeight),
    ];

    for (final label in yLabels) {
      final tp = TextPainter(
        text: TextSpan(
          text: label.$1,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(6, label.$2 - tp.height / 2));
    }

    final xLabels = [
      '24 Feb',
      '3 Mar',
      '10 Mar',
      '17 Mar',
      '24 Mar',
      '31 Mar',
      '7 Apr',
      '14 Apr',
      '21 Apr',
      '28 Apr',
      '5 May',
      '12 May',
      '26 May',
      '9 Jun',
    ];

    for (var i = 0; i < xLabels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: xLabels[i],
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = left + (chartWidth / (xLabels.length - 1)) * i - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 18));
    }
  }

  void _drawDashedSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final ux = dx / distance;
    final uy = dy / distance;
    var traveled = 0.0;

    while (traveled < distance) {
      final dashEnd = math.min(traveled + dashLength, distance);
      canvas.drawLine(
        Offset(start.dx + ux * traveled, start.dy + uy * traveled),
        Offset(start.dx + ux * dashEnd, start.dy + uy * dashEnd),
        paint,
      );
      traveled += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _RecommendationRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final String amount;
  final String amountHint;
  final Color amountColor;
  final Color accent;

  const _RecommendationRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountHint,
    required this.amountColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        amountHint,
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                amountHint,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final Color amountColor;
  final IconData icon;
  final Color iconColor;

  const _TransactionRow({
    required this.title,
    required this.date,
    required this.amount,
    required this.amountColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sectionRow(
  String title,
  String subtitle, {
  String? actionText,
  VoidCallback? onAction,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
      if (actionText != null)
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: Text(actionText),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

Color _severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'high':
      return const Color(0xFFF59E0B);
    case 'medium':
      return const Color(0xFFEAB308);
    case 'low':
    default:
      return const Color(0xFF64748B);
  }
}

Color _severityBackground(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return const Color(0xFFFFF1F2);
    case 'high':
      return const Color(0xFFFFFBEB);
    case 'medium':
      return const Color(0xFFFEFCE8);
    case 'low':
    default:
      return const Color(0xFFF8FAFC);
  }
}

class DashboardData {
  final String businessName;
  final String currency;
  final String asOfDate;
  final DashboardKpis kpis;
  final DashboardAlert? alert;
  final List<DashboardRiskRow> risks;
  final List<DashboardRecommendationRow> recommendations;
  final List<DashboardTransactionRow> recentTransactions;

  const DashboardData({
    required this.businessName,
    required this.currency,
    required this.asOfDate,
    required this.kpis,
    required this.alert,
    required this.risks,
    required this.recommendations,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final business = (json['business'] as Map<String, dynamic>?) ?? const {};
    final kpis = (json['kpis'] as Map<String, dynamic>?) ?? const {};
    final alert = json['alert'] as Map<String, dynamic>?;
    final riskSummary =
        (json['risk_summary'] as Map<String, dynamic>?) ?? const {};
    final recommendationSummary =
        (json['recommendations'] as Map<String, dynamic>?) ?? const {};
    final transactionSummary =
        (json['recent_transactions'] as Map<String, dynamic>?) ?? const {};

    return DashboardData(
      businessName: business['name']?.toString() ?? 'Business',
      currency: business['currency']?.toString() ?? 'MYR',
      asOfDate: json['as_of_date']?.toString() ?? '',
      kpis: DashboardKpis.fromJson(kpis),
      alert: alert == null ? null : DashboardAlert.fromJson(alert),
      risks: _parseRiskRows(riskSummary['rows']),
      recommendations: _parseRecommendationRows(recommendationSummary['rows']),
      recentTransactions: _parseTransactionRows(transactionSummary['rows']),
    );
  }
}

class DashboardAlert {
  final String title;
  final String subtitle;

  const DashboardAlert({required this.title, required this.subtitle});

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }
}

class DashboardKpis {
  final int currentBalance;
  final int currentBalanceDelta;
  final int monthlyRevenue;
  final int monthlyRevenueDelta;
  final int monthlyExpenses;
  final int monthlyExpensesDelta;
  final int outstandingInvoices;
  final int outstandingInvoicesCount;

  const DashboardKpis({
    required this.currentBalance,
    required this.currentBalanceDelta,
    required this.monthlyRevenue,
    required this.monthlyRevenueDelta,
    required this.monthlyExpenses,
    required this.monthlyExpensesDelta,
    required this.outstandingInvoices,
    required this.outstandingInvoicesCount,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num? ?? 0).round();

    return DashboardKpis(
      currentBalance: readInt('current_balance'),
      currentBalanceDelta: readInt('current_balance_delta'),
      monthlyRevenue: readInt('monthly_revenue'),
      monthlyRevenueDelta: readInt('monthly_revenue_delta'),
      monthlyExpenses: readInt('monthly_expenses'),
      monthlyExpensesDelta: readInt('monthly_expenses_delta'),
      outstandingInvoices: readInt('outstanding_invoices'),
      outstandingInvoicesCount: readInt('outstanding_invoices_count'),
    );
  }
}

class DashboardRiskRow {
  final String title;
  final String subtitle;
  final String severity;
  final num affectedAmount;

  const DashboardRiskRow({
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.affectedAmount,
  });

  factory DashboardRiskRow.fromJson(Map<String, dynamic> json) {
    return DashboardRiskRow(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'medium',
      affectedAmount: json['affected_amount'] as num? ?? 0,
    );
  }
}

class DashboardRecommendationRow {
  final int index;
  final String title;
  final String subtitle;
  final String amount;
  final num amountValue;
  final String amountHint;

  const DashboardRecommendationRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountValue,
    required this.amountHint,
  });

  factory DashboardRecommendationRow.fromJson(Map<String, dynamic> json) {
    return DashboardRecommendationRow(
      index: (json['index'] as num? ?? 0).round(),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      amountValue: json['amount_value'] as num? ?? 0,
      amountHint: json['amount_hint']?.toString() ?? 'impact',
    );
  }
}

class DashboardTransactionRow {
  final String title;
  final String date;
  final String amount;
  final num amountValue;

  const DashboardTransactionRow({
    required this.title,
    required this.date,
    required this.amount,
    required this.amountValue,
  });

  factory DashboardTransactionRow.fromJson(Map<String, dynamic> json) {
    return DashboardTransactionRow(
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      amountValue: json['amount_value'] as num? ?? 0,
    );
  }
}

List<DashboardRiskRow> _parseRiskRows(dynamic rows) {
  final list = rows as List<dynamic>? ?? const [];
  return list
      .whereType<Map>()
      .map((row) => DashboardRiskRow.fromJson(Map<String, dynamic>.from(row)))
      .toList();
}

List<DashboardRecommendationRow> _parseRecommendationRows(dynamic rows) {
  final list = rows as List<dynamic>? ?? const [];
  return list
      .whereType<Map>()
      .map(
        (row) =>
            DashboardRecommendationRow.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList();
}

List<DashboardTransactionRow> _parseTransactionRows(dynamic rows) {
  final list = rows as List<dynamic>? ?? const [];
  return list
      .whereType<Map>()
      .map(
        (row) =>
            DashboardTransactionRow.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList();
}
