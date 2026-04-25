import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardContent extends StatefulWidget {
  final String businessId;
  final String apiBaseUrl;
  final VoidCallback? onGoToRecommendations;
  final VoidCallback? onGoToRisks;
  final VoidCallback? onGoToTransactions;

  const DashboardContent({
    super.key,
    required this.businessId,
    required this.apiBaseUrl,
    this.onGoToRecommendations,
    this.onGoToRisks,
    this.onGoToTransactions,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final uri = Uri.parse('${widget.apiBaseUrl}/api/dashboard/${widget.businessId}');
      final response = await http.get(uri, headers: {'Accept': 'application/json'});
      final payload = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Dashboard API failed (${response.statusCode})');
      }

      if (payload is! Map<String, dynamic> || payload['success'] != true) {
        throw Exception((payload is Map<String, dynamic>)
            ? (payload['error']?.toString() ?? 'Dashboard API returned error')
            : 'Invalid dashboard response');
      }

      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Dashboard data payload missing');
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _rm(int value) {
    final abs = value.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final sign = value < 0 ? '-' : '';
    return '$sign' 'RM $abs';
  }

  String _deltaLabel(int delta) {
    final direction = delta >= 0 ? 'UP' : 'DOWN';
    final abs = delta.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '$direction RM $abs';
  }

  Color _deltaColor(int delta, {bool negativeIsGood = false}) {
    if (delta == 0) return const Color(0xFF64748B);
    if (negativeIsGood) {
      return delta < 0 ? const Color(0xFF059669) : const Color(0xFFEF4444);
    }
    return delta > 0 ? const Color(0xFF059669) : const Color(0xFFEF4444);
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _friendlyDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
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
        color: color.withValues(alpha: 0.10),
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
                    color: iconColor.withValues(alpha: 0.10),
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
        border: Border.all(color: accent.withValues(alpha: 0.32)),
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
                    color: accent.withValues(alpha: 0.95),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 36),
              const SizedBox(height: 10),
              Text(
                'Unable to load dashboard\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF991B1B)),
              ),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final kpis = Map<String, dynamic>.from((_data['kpis'] as Map?) ?? const {});
    final alert = Map<String, dynamic>.from((_data['alert'] as Map?) ?? const {});
    final riskSummary = Map<String, dynamic>.from((_data['risk_summary'] as Map?) ?? const {});
    final recommendations = Map<String, dynamic>.from((_data['recommendations'] as Map?) ?? const {});
    final recentTransactions = Map<String, dynamic>.from((_data['recent_transactions'] as Map?) ?? const {});

    final riskRows = _rows(riskSummary['rows']);
    final recommendationRows = _rows(recommendations['rows']);
    final transactionRows = _rows(recentTransactions['rows']);

    final currentBalance = _toInt(kpis['current_balance']);
    final currentBalanceDelta = _toInt(kpis['current_balance_delta']);
    final monthlyRevenue = _toInt(kpis['monthly_revenue']);
    final monthlyRevenueDelta = _toInt(kpis['monthly_revenue_delta']);
    final monthlyExpenses = _toInt(kpis['monthly_expenses']);
    final monthlyExpensesDelta = _toInt(kpis['monthly_expenses_delta']);
    final outstandingInvoices = _toInt(kpis['outstanding_invoices']);
    final outstandingInvoicesCount = _toInt(kpis['outstanding_invoices_count']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1180;
        final horizontalPadding = constraints.maxWidth < 900 ? 16.0 : 20.0;

        final metricCards = [
          _metricCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF2563EB),
            change: _deltaLabel(currentBalanceDelta),
            changeColor: _deltaColor(currentBalanceDelta),
            value: _rm(currentBalance),
            title: 'Current Balance',
            subtitle: 'vs last month',
          ),
          _metricCard(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF10B981),
            change: _deltaLabel(monthlyRevenueDelta),
            changeColor: _deltaColor(monthlyRevenueDelta),
            value: _rm(monthlyRevenue),
            title: 'Monthly Revenue',
            subtitle: 'current month',
          ),
          _metricCard(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFFF59E0B),
            change: _deltaLabel(monthlyExpensesDelta),
            changeColor: _deltaColor(monthlyExpensesDelta, negativeIsGood: true),
            value: _rm(monthlyExpenses),
            title: 'Monthly Expenses',
            subtitle: 'current month',
          ),
          _metricCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFEF4444),
            change: 'Open',
            changeColor: const Color(0xFFEF4444),
            value: _rm(outstandingInvoices),
            title: 'Outstanding Invoices',
            subtitle: '$outstandingInvoicesCount invoices pending',
          ),
        ];

        final metricGrid = isCompact
            ? Column(
                children: [
                  for (int i = 0; i < metricCards.length; i++) ...[
                    metricCards[i],
                    if (i != metricCards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              )
            : Row(
                children: [
                  for (int i = 0; i < metricCards.length; i++) ...[
                    Expanded(child: metricCards[i]),
                    if (i != metricCards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );

        const topCardHeight = 500.0;
        const sideCardWidth = 332.0;
        const bottomCardHeight = 420.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 24),
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
                      _friendlyDate((_data['as_of_date'] ?? '').toString()),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              _cardShell(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFFBEB),
                        const Color(0xFFFFF7ED).withValues(alpha: 0.9),
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
                              (alert['title'] ?? 'Latest cash flow status').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (alert['subtitle'] ?? 'No forecast alert currently available.').toString(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
              const SizedBox(height: 14),
              metricGrid,
              const SizedBox(height: 14),
              if (isCompact) ...[
                _TrendCard(cardShell: _cardShell, alertText: (alert['subtitle'] ?? '').toString()),
                const SizedBox(height: 14),
                _RecommendationsCard(
                  cardShell: _cardShell,
                  onViewAll: widget.onGoToRecommendations,
                  rows: recommendationRows,
                  totalActive: _toInt(recommendations['total_active']),
                ),
                const SizedBox(height: 14),
                _RiskCard(
                  cardShell: _cardShell,
                  riskTile: _riskTile,
                  onViewAll: widget.onGoToRisks,
                  rows: riskRows,
                  totalActive: _toInt(riskSummary['total_active']),
                ),
                const SizedBox(height: 14),
                _TransactionsCard(
                  cardShell: _cardShell,
                  onViewAll: widget.onGoToTransactions,
                  rows: transactionRows,
                  totalCount: _toInt(recentTransactions['total']),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: topCardHeight,
                        child: _TrendCard(cardShell: _cardShell, alertText: (alert['subtitle'] ?? '').toString()),
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
                        rows: riskRows,
                        totalActive: _toInt(riskSummary['total_active']),
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
                          rows: recommendationRows,
                          totalActive: _toInt(recommendations['total_active']),
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
                        rows: transactionRows,
                        totalCount: _toInt(recentTransactions['total']),
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
  final String alertText;

  const _TrendCard({required this.cardShell, required this.alertText});

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertText.isEmpty ? 'No shortfall projected in the active window.' : alertText,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
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
  final int totalActive;
  final List<Map<String, dynamic>> rows;

  const _RiskCard({
    required this.cardShell,
    required this.riskTile,
    this.onViewAll,
    required this.totalActive,
    required this.rows,
  });

  ({Color accent, Color background}) _severityColors(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return (accent: const Color(0xFFEF4444), background: const Color(0xFFFFF1F2));
      case 'low':
        return (accent: const Color(0xFF10B981), background: const Color(0xFFECFDF5));
      case 'medium':
      default:
        return (accent: const Color(0xFFF59E0B), background: const Color(0xFFFFFBEB));
    }
  }

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
              '$totalActive risks detected',
              actionText: 'View all',
              onAction: onViewAll,
            ),
            const SizedBox(height: 12),
            ...rows.take(4).map((row) {
              final colors = _severityColors((row['severity'] ?? 'medium').toString());
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: riskTile(
                  title: (row['title'] ?? 'Risk alert').toString(),
                  subtitle: (row['subtitle'] ?? '').toString(),
                  accent: colors.accent,
                  background: colors.background,
                ),
              );
            }),
            if (rows.isEmpty)
              riskTile(
                title: 'No active risk alerts',
                subtitle: 'Your risk monitor is currently clear.',
                accent: const Color(0xFF10B981),
                background: const Color(0xFFECFDF5),
              ),
            const SizedBox(height: 12),
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
}

class _RecommendationsCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;
  final VoidCallback? onViewAll;
  final int totalActive;
  final List<Map<String, dynamic>> rows;

  const _RecommendationsCard({
    required this.cardShell,
    this.onViewAll,
    required this.totalActive,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionRow(
                  'AI Recommendations',
                  'Top 3 actions by impact',
                  actionText: 'View all $totalActive',
                  onAction: onViewAll,
                ),
                const SizedBox(height: 12),
                ...rows.take(3).map((row) {
                  final amountValue = int.tryParse((row['amount_value'] ?? '0').toString()) ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecommendationRow(
                      index: int.tryParse((row['index'] ?? '1').toString()) ?? 1,
                      title: (row['title'] ?? 'Recommendation').toString(),
                      subtitle: (row['subtitle'] ?? 'Action recommended').toString(),
                      amount: (row['amount'] ?? '+RM 0').toString(),
                      amountHint: (row['amount_hint'] ?? 'impact').toString(),
                      amountColor: amountValue >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                      accent: const Color(0xFF2563EB),
                    ),
                  );
                }),
                if (rows.isEmpty)
                  const _RecommendationRow(
                    index: 1,
                    title: 'No active recommendations',
                    subtitle: 'Generate recommendations from the risks page.',
                    amount: '+RM 0',
                    amountHint: 'impact',
                    amountColor: Color(0xFF64748B),
                    accent: Color(0xFF2563EB),
                  ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rows.isEmpty
                              ? 'No recommendation impact available yet. Trigger AI recommendation generation to populate this panel.'
                              : 'Following top recommendations can improve your short-term cash buffer.',
                          style: const TextStyle(
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
            );

            if (constraints.maxHeight.isFinite) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: content,
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  final Widget Function({required Widget child}) cardShell;
  final VoidCallback? onViewAll;
  final int totalCount;
  final List<Map<String, dynamic>> rows;

  const _TransactionsCard({
    required this.cardShell,
    this.onViewAll,
    required this.totalCount,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionRow(
                  'Recent Transactions',
                  '$totalCount total extracted',
                  actionText: 'All',
                  onAction: onViewAll,
                ),
                const SizedBox(height: 12),
                ...rows.take(6).map((row) {
                  final direction = (row['direction'] ?? '').toString().toLowerCase();
                  final isInflow = direction == 'inflow';
                  return _TransactionRow(
                    title: (row['title'] ?? 'Transaction').toString(),
                    date: (row['date'] ?? '').toString(),
                    amount: (row['amount'] ?? (isInflow ? '+RM 0' : '-RM 0')).toString(),
                    amountColor: isInflow ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                    icon: isInflow ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    iconColor: isInflow ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  );
                }),
                if (rows.isEmpty)
                  const _TransactionRow(
                    title: 'No transactions available',
                    date: '-',
                    amount: 'RM 0',
                    amountColor: Color(0xFF64748B),
                    icon: Icons.remove,
                    iconColor: Color(0xFF94A3B8),
                  ),
              ],
            );

            if (constraints.maxHeight.isFinite) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: content,
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
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
    final paintForecast = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const left = 40.0;
    const right = 14.0;
    const top = 12.0;
    const bottom = 30.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    for (var i = 0; i < 5; i++) {
      final y = top + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        paintGrid,
      );
    }

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

    final historicalPath = Path()..moveTo(historicalPoints.first.dx, historicalPoints.first.dy);
    for (final point in historicalPoints.skip(1)) {
      historicalPath.lineTo(point.dx, point.dy);
    }
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
      final de = math.min(traveled + dashLength, distance);
      canvas.drawLine(
        Offset(start.dx + ux * traveled, start.dy + uy * traveled),
        Offset(start.dx + ux * de, start.dy + uy * de),
        paint,
      );
      traveled += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
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
              color: iconColor.withValues(alpha: 0.14),
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
