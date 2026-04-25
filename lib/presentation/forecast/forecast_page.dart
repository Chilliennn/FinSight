// lib/presentation/forecast/forecast_page.dart
//
// Cash Flow Forecast Display
// - Top KPI cards
// - Combined bar + line chart
// - Detailed 8-week forecast table

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ForecastContent extends StatefulWidget {
  final VoidCallback? onGoToDashboard;
  final String businessId;
  final String apiBaseUrl;

  const ForecastContent({
    super.key,
    this.onGoToDashboard,
    required this.businessId,
    required this.apiBaseUrl,
  });

  @override
  State<ForecastContent> createState() => _ForecastContentState();
}

class _ForecastContentState extends State<ForecastContent> {
  bool _isLoading = true;
  Map<String, dynamic> _forecastData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadForecastData();
  }

  Future<void> _loadForecastData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      var decoded = await _fetchForecastEnvelope(allowNotFound: true);
      if (decoded['success'] != true) {
        await _generateForecastInBackend();
        decoded = await _fetchForecastEnvelope();
      }

      final rawData = decoded['data'];
      if (rawData is! Map<String, dynamic>) {
        throw Exception('Forecast data payload missing or invalid');
      }

      if (!mounted) return;
      setState(() {
        _forecastData = _normalizeForecastData(rawData);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load forecast from backend. ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchForecastEnvelope({bool allowNotFound = false}) async {
    final uri = Uri.parse('${widget.apiBaseUrl}/api/forecast/${widget.businessId}');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid forecast response format');
    }

    if (response.statusCode == 404 && allowNotFound) {
      return {'success': false, 'data': null, 'error': decoded['error'] ?? 'No forecast found'};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Forecast API failed (${response.statusCode}): ${decoded['error'] ?? response.body}');
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Forecast API returned error');
    }

    return decoded;
  }

  Future<void> _generateForecastInBackend() async {
    final uri = Uri.parse('${widget.apiBaseUrl}/api/forecast/generate');
    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'businessId': widget.businessId,
        'projectionDays': 56,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid forecast generation response format');
    }

    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Failed to generate forecast from backend');
    }
  }

  Future<void> _regenerateForecast() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      await _generateForecastInBackend();
      await _loadForecastData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to regenerate forecast. ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeForecastData(Map<String, dynamic> raw) {
    final weeklyRaw = (raw['weekly_totals'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final projectionStart = DateTime.tryParse(
      (raw['projection_start_date'] ?? raw['generated_at'] ?? '').toString(),
    );

    final weekly = <Map<String, dynamic>>[];
    for (int i = 0; i < weeklyRaw.length; i++) {
      final row = weeklyRaw[i];
      final weekNumber = _toInt(row['week'], fallback: i + 1);
      final periodDate = projectionStart?.add(Duration(days: (weekNumber - 1) * 7));
      final period = periodDate != null ? DateFormat('d MMM').format(periodDate) : 'W$weekNumber';

      weekly.add({
        'week': weekNumber,
        'period': period,
        'total_inflow': _toInt(row['total_inflow']),
        'total_outflow': _toInt(row['total_outflow']),
        'net_flow': _toInt(row['net_flow']),
        'end_of_week_balance': _toInt(row['end_of_week_balance']),
      });
    }

    final minBal = weekly.isEmpty
        ? 0
        : weekly
            .map((w) => w['end_of_week_balance'] as int)
            .reduce((a, b) => math.min(a, b));

    final avgIn = weekly.isEmpty
        ? 0
        : (weekly.fold<int>(0, (s, w) => s + (w['total_inflow'] as int)) /
                weekly.length)
            .round();

    final avgOut = weekly.isEmpty
        ? 0
        : (weekly.fold<int>(0, (s, w) => s + (w['total_outflow'] as int)) /
                weekly.length)
            .round();

    final risk = Map<String, dynamic>.from((raw['risk_summary'] as Map?) ?? const {});
    final shortfallDate = (risk['projected_shortfall_date'] ?? '').toString();
    final minProjectedBalance = _toInt(risk['minimum_projected_balance'], fallback: minBal);
    final atRiskDays = _toInt(risk['at_risk_days']);
    final hasShortfallRisk = risk['has_shortfall_risk'] == true || minProjectedBalance < 0;

    final ai = Map<String, dynamic>.from((raw['ai_insights'] as Map?) ?? const {});
    final generatedAt = DateTime.tryParse((raw['generated_at'] ?? '').toString()) ?? DateTime.now();

    return {
      'business_id': raw['business_id'] ?? widget.businessId,
      'current_balance': _toInt(raw['current_balance']),
      'generated_at': generatedAt.toIso8601String(),
      'projection_period_days': _toInt(raw['projection_period_days'], fallback: 56),
      'weekly_totals': weekly,
      'risk_summary': {
        'risk_level': (risk['risk_level'] ?? 'Low').toString(),
        'minimum_projected_balance': minProjectedBalance,
        'projected_shortfall_date': shortfallDate,
        'at_risk_days': atRiskDays,
        'has_shortfall_risk': hasShortfallRisk,
      },
      'kpis': {
        'avg_weekly_inflow': avgIn,
        'avg_weekly_outflow': avgOut,
      },
      'cash_gap_note': hasShortfallRisk
          ? (shortfallDate.isNotEmpty
              ? 'Cash gap projected around $shortfallDate. Review outflows and apply recommendations early.'
              : 'Cash shortfall risk detected in this forecast window. Review outflow-heavy weeks now.')
          : 'No shortfall risk projected in the current forecast window.',
      'ai_insights': {
        'summary': (ai['summary'] ?? 'Forecast loaded from backend.').toString(),
        'warnings': (ai['warnings'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        'opportunities': (ai['opportunities'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        'recommended_actions': (ai['recommended_actions'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      },
    };
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _rm(num value, {bool withSign = false}) {
    final abs = value.abs().toStringAsFixed(0);
    if (withSign) {
      final sign = value >= 0 ? '+' : '-';
      return '${sign}RM $abs';
    }
    return 'RM $abs';
  }

  List<Map<String, dynamic>> _weeklyTotals() {
    return (_forecastData['weekly_totals'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Failed to load forecast', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(_errorMessage!),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadForecastData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Flow Forecast',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '8-week projection based on historical patterns',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.tryParse((_forecastData['generated_at'] ?? '').toString()) ?? DateTime.now())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadForecastData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                  FilledButton.icon(
                    onPressed: _regenerateForecast,
                    icon: const Icon(Icons.auto_graph, size: 18),
                    label: const Text('Regenerate'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1) Top 4 KPI components.
          _buildTopKpiRow(),
          const SizedBox(height: 18),

          // 2) Combined bar + line graph.
          _buildCombinedGraphCard(),
          const SizedBox(height: 18),

          // 3) Detailed forecast below graph.
          _buildDetailedForecastCard(),
          const SizedBox(height: 18),

          _buildRecommendationBanner(),
        ],
      ),
    );
  }

  Widget _buildTopKpiRow() {
    final kpi = _forecastData['kpis'] as Map<String, dynamic>;
    final risk = _forecastData['risk_summary'] as Map<String, dynamic>;
    final currentBalance = (_forecastData['current_balance'] ?? 0) as int;
    final minBalance = (risk['minimum_projected_balance'] ?? 0) as int;
    final riskLevel = (risk['risk_level'] ?? 'Low').toString();
    final atRiskDays = (risk['at_risk_days'] ?? 0) as int;
    final minBalanceSubtitle = atRiskDays > 0
        ? '$riskLevel risk • $atRiskDays at-risk day${atRiskDays == 1 ? '' : 's'}'
        : '$riskLevel risk • no at-risk days';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _kpiCard(
            title: 'Current Balance',
            value: _rm(currentBalance),
            subtitle: 'As of today',
            icon: Icons.account_balance_wallet_outlined,
            tint: const Color(0xFF2563EB),
            border: const Color(0xFFE2E8F0),
          ),
          _kpiCard(
            title: 'Avg Weekly Inflow',
            value: _rm(kpi['avg_weekly_inflow'] as int),
            subtitle: 'Forecast horizon average',
            icon: Icons.trending_up,
            tint: const Color(0xFF059669),
            border: const Color(0xFFA7F3D0),
          ),
          _kpiCard(
            title: 'Avg Weekly Outflow',
            value: _rm(kpi['avg_weekly_outflow'] as int),
            subtitle: 'Forecast horizon average',
            icon: Icons.trending_down,
            tint: const Color(0xFFDC2626),
            border: const Color(0xFFFECACA),
          ),
          _kpiCard(
            title: 'Projected Min Balance',
            value: _rm(minBalance, withSign: minBalance < 0),
            subtitle: minBalanceSubtitle,
            icon: Icons.warning_amber_rounded,
            tint: const Color(0xFFDC2626),
            border: const Color(0xFFFECACA),
          ),
        ];

        if (constraints.maxWidth >= 980) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: tint),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontWeight: FontWeight.w800,
              fontSize: 28,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCombinedGraphCard() {
    final weekly = _weeklyTotals();

    return _cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Inflow vs Outflow + Balance Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bars represent inflow and outflow, line represents projected balance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: CustomPaint(
                painter: _CombinedForecastPainter(weekly: weekly),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _legendBox('Inflow', const Color(0xFF34D399)),
                _legendBox('Outflow', const Color(0xFFF87171)),
                _legendLine('Balance', const Color(0xFF2563EB)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _forecastData['cash_gap_note'] as String,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendBox(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendLine(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 24, height: 2, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailedForecastCard() {
    final weekly = _weeklyTotals();

    return _cardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '8-Week Detailed Forecast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Weekly inflow, outflow, net and projected balance breakdown',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 56,
                headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Week')),
                  DataColumn(label: Text('Period')),
                  DataColumn(label: Text('Projected Inflow')),
                  DataColumn(label: Text('Projected Outflow')),
                  DataColumn(label: Text('Net')),
                  DataColumn(label: Text('Projected Balance')),
                  DataColumn(label: Text('Status')),
                ],
                rows: weekly.map((w) {
                  final inflow = w['total_inflow'] as int;
                  final outflow = w['total_outflow'] as int;
                  final net = w['net_flow'] as int;
                  final bal = w['end_of_week_balance'] as int;
                  final isGap = bal < 0;

                  return DataRow(
                    color: isGap
                        ? const WidgetStatePropertyAll(Color(0xFFFEF2F2))
                        : null,
                    cells: [
                      DataCell(Text('Week ${w['week']}')),
                      DataCell(Text(w['period'] as String)),
                      DataCell(Text(_rm(inflow, withSign: true), style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700))),
                      DataCell(Text(_rm(outflow, withSign: true).replaceFirst('+', '-'), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700))),
                      DataCell(Text(_rm(net, withSign: true), style: TextStyle(color: net >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), fontWeight: FontWeight.w700))),
                      DataCell(Text(_rm(bal, withSign: isGap), style: TextStyle(color: isGap ? const Color(0xFFDC2626) : const Color(0xFF0F172A), fontWeight: FontWeight.w800))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isGap ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isGap ? 'CASH GAP' : 'SAFE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isGap ? const Color(0xFFDC2626) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationBanner() {
    final ai = _forecastData['ai_insights'] as Map<String, dynamic>;
    final summary = (ai['summary'] ?? '') as String;
    final warnings = (ai['warnings'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final opportunities = (ai['opportunities'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final recommendedActions =
        (ai['recommended_actions'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final insights = [
      ...recommendedActions.take(2).map((i) => 'Action: $i'),
      ...warnings.take(1).map((i) => 'Risk: $i'),
      ...opportunities.take(1).map((i) => 'Opportunity: $i'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF166534)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $insight',
                  style: const TextStyle(color: Color(0xFF166534), fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CombinedForecastPainter extends CustomPainter {
  final List<Map<String, dynamic>> weekly;

  _CombinedForecastPainter({required this.weekly});

  @override
  void paint(Canvas canvas, Size size) {
    if (weekly.isEmpty) return;

    const topPad = 10.0;
    const bottomPad = 14.0;
    final usableHeight = size.height - topPad - bottomPad;
    final groupW = size.width / weekly.length;
    final barW = groupW * 0.30;

    final maxVal = weekly
        .map((w) => [
              (w['total_inflow'] as int).toDouble(),
              (w['total_outflow'] as int).toDouble(),
              (w['end_of_week_balance'] as int).abs().toDouble(),
            ])
        .expand((v) => v)
        .reduce(math.max)
        .clamp(1, double.infinity);

    final inflowPaint = Paint()..color = const Color(0xFF34D399);
    final outflowPaint = Paint()..color = const Color(0xFFF87171);
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = topPad + (usableHeight * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePts = <Offset>[];

    for (int i = 0; i < weekly.length; i++) {
      final row = weekly[i];
      final inflow = (row['total_inflow'] as int).toDouble();
      final outflow = (row['total_outflow'] as int).toDouble();
      final balance = (row['end_of_week_balance'] as int).toDouble();

      final xCenter = (groupW * i) + (groupW / 2);

      final inflowH = (inflow / maxVal) * usableHeight;
      final outflowH = (outflow / maxVal) * usableHeight;
      final balanceH = (balance.abs() / maxVal) * usableHeight;
      final balanceY = topPad + usableHeight - balanceH;

      final inflowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xCenter - barW - 2,
          topPad + usableHeight - inflowH,
          barW,
          inflowH,
        ),
        const Radius.circular(4),
      );

      final outflowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xCenter + 2,
          topPad + usableHeight - outflowH,
          barW,
          outflowH,
        ),
        const Radius.circular(4),
      );

      canvas.drawRRect(inflowRect, inflowPaint);
      canvas.drawRRect(outflowRect, outflowPaint);

      linePts.add(Offset(xCenter, balanceY));
    }

    for (int i = 0; i < linePts.length - 1; i++) {
      canvas.drawLine(linePts[i], linePts[i + 1], linePaint);
    }

    final pointPaint = Paint()..color = const Color(0xFF2563EB);
    for (final p in linePts) {
      canvas.drawCircle(p, 3.2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CombinedForecastPainter oldDelegate) {
    return oldDelegate.weekly != weekly;
  }
}
