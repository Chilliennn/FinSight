// lib/presentation/dashboard/dashboard_page.dart
//
// Changes from original:
//   1. _sectionRow() gains a BuildContext + optional VoidCallback onAction parameter.
//      All "View all" / "All" buttons now call that callback instead of () {}.
//   2. _RecommendationsCard gains onViewAll VoidCallback → passed by DashboardContent.
//   3. _RiskCard gains onViewAll VoidCallback → passed by DashboardContent.
//   4. DashboardContent gains optional onGoToRecommendations / onGoToRisks callbacks.
//      main.dart (or whoever builds DashboardContent) passes the Navigator calls in.
//   5. "View Risks" alert banner button calls onGoToRisks.
//   6. NO new imports needed — no circular dependency risk.
//   7. All other code is IDENTICAL to the original.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashboardContent extends StatelessWidget {
  // ── Navigation callbacks injected by the parent (main.dart / AppLayout) ──
  // Using callbacks instead of importing AppLayout keeps this file
  // free of circular dependencies.
  final VoidCallback? onGoToRecommendations;
  final VoidCallback? onGoToRisks;

  const DashboardContent({
    super.key,
    this.onGoToRecommendations,
    this.onGoToRisks,
  });

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1180;
        final horizontalPadding = constraints.maxWidth < 900 ? 16.0 : 20.0;

        final metricCards = [
          _metricCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF2563EB),
            change: '↘ 8%',
            changeColor: const Color(0xFFEF4444),
            value: 'RM 28,450',
            title: 'Current Balance',
            subtitle: 'vs last month',
          ),
          _metricCard(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF10B981),
            change: '↘ 15%',
            changeColor: const Color(0xFFEF4444),
            value: 'RM 42,800',
            title: 'Monthly Revenue',
            subtitle: 'vs March 2026',
          ),
          _metricCard(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFFF59E0B),
            change: '↗ 6%',
            changeColor: const Color(0xFF059669),
            value: 'RM 38,920',
            title: 'Monthly Expenses',
            subtitle: 'vs March 2026',
          ),
          _metricCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFEF4444),
            change: '↘ 12%',
            changeColor: const Color(0xFFEF4444),
            value: 'RM 18,200',
            title: 'Outstanding Invoices',
            subtitle: '3 invoices pending',
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

        const topCardHeight    = 500.0;
        const sideCardWidth    = 332.0;
        const bottomCardHeight = 420.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding, 18, horizontalPadding, 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '16 Apr 2026',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ── Critical alert banner ─────────────────────────────────────
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
                        width: 38, height: 38,
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Critical Alert: Cash flow gap projected in 6 weeks',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Projected balance of - RM 2,550 by 26 May 2026 • 3 overdue invoices totalling RM 18,200',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        // ── Calls onGoToRisks callback ─────────────────────
                        onPressed: onGoToRisks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14,
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
              const SizedBox(height: 14),
              metricGrid,
              const SizedBox(height: 14),

              if (isCompact) ...[
                _TrendCard(cardShell: _cardShell),
                const SizedBox(height: 14),
                _RecommendationsCard(
                  cardShell: _cardShell,
                  onViewAll: onGoToRecommendations, // ← wired
                ),
                const SizedBox(height: 14),
                _RiskCard(
                  cardShell: _cardShell,
                  riskTile:  _riskTile,
                  onViewAll: onGoToRisks,           // ← wired
                ),
                const SizedBox(height: 14),
                _TransactionsCard(cardShell: _cardShell),
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
                        riskTile:  _riskTile,
                        onViewAll: onGoToRisks,     // ← wired
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
                          onViewAll: onGoToRecommendations, // ← wired
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: sideCardWidth,
                      height: bottomCardHeight,
                      child: _TransactionsCard(cardShell: _cardShell),
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

// ─── Cards ────────────────────────────────────────────────────────────────────

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
  }) riskTile;
  final VoidCallback? onViewAll; // ← NEW

  const _RiskCard({
    required this.cardShell,
    required this.riskTile,
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
              '5 risks detected',
              actionText: 'View all',
              onAction: onViewAll, // ← wired
            ),
            const SizedBox(height: 12),
            riskTile(
              title: 'Cash Flow Gap in 6 Weeks',
              subtitle: 'RM 2,550 affected • Week 6',
              accent: const Color(0xFFEF4444),
              background: const Color(0xFFFFF1F2),
            ),
            const SizedBox(height: 10),
            riskTile(
              title: '3 Overdue Invoices Unpaid',
              subtitle: 'RM 18,200 affected',
              accent: const Color(0xFFF59E0B),
              background: const Color(0xFFFFFBEB),
            ),
            const SizedBox(height: 10),
            riskTile(
              title: 'Operating Expenses Up 28% vs Last Month',
              subtitle: 'RM 6,800 affected',
              accent: const Color(0xFFF59E0B),
              background: const Color(0xFFFFFBEB),
            ),
            const SizedBox(height: 10),
            riskTile(
              title: 'Revenue Declining 3 Consecutive Months',
              subtitle: 'RM 7,500 affected',
              accent: const Color(0xFFF59E0B),
              background: const Color(0xFFFFFBEB),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewAll, // ← wired
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
  final VoidCallback? onViewAll; // ← NEW

  const _RecommendationsCard({
    required this.cardShell,
    this.onViewAll,
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
                  actionText: 'View all 5',
                  onAction: onViewAll, // ← wired
                ),
                const SizedBox(height: 12),
                const _RecommendationRow(
                  index: 1,
                  title: 'Collect Overdue Invoice from TechCorp (INV-2026-089)',
                  subtitle: 'Within 7 days • easy',
                  amount: '+RM 8,500',
                  amountHint: 'cash in',
                  amountColor: Color(0xFF16A34A),
                  accent: Color(0xFF2563EB),
                ),
                const SizedBox(height: 10),
                const _RecommendationRow(
                  index: 2,
                  title: 'Negotiate 14-Day Extension with Sunrise Ingredients',
                  subtitle: 'Within 2 weeks • easy',
                  amount: '+RM 12,000',
                  amountHint: 'buffer',
                  amountColor: Color(0xFFF97316),
                  accent: Color(0xFF2563EB),
                ),
                const SizedBox(height: 10),
                const _RecommendationRow(
                  index: 3,
                  title: 'Follow Up on Axiata Invoice (INV-2026-112)',
                  subtitle: 'Within 10 days • easy',
                  amount: '+RM 5,500',
                  amountHint: 'cash in',
                  amountColor: Color(0xFF16A34A),
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
                          'Following top 3 recommendations prevents the cash gap and adds +RM 24,000 to your buffer.',
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
  const _TransactionsCard({required this.cardShell});

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
                  '42 total extracted',
                  actionText: 'All',
                  // Transactions page not built yet — shows SnackBar
                  onAction: null,
                ),
                const SizedBox(height: 12),
                const _TransactionRow(
                  title: 'Malayan Banking Berhad',
                  date: '2026-04-16',
                  amount: '+RM 4,200',
                  amountColor: Color(0xFF16A34A),
                  icon: Icons.trending_up_rounded,
                  iconColor: Color(0xFF34D399),
                ),
                const _TransactionRow(
                  title: 'Meta Business',
                  date: '2026-04-15',
                  amount: '-RM 1,200',
                  amountColor: Color(0xFFEF4444),
                  icon: Icons.trending_down_rounded,
                  iconColor: Color(0xFFF87171),
                ),
                const _TransactionRow(
                  title: 'Fresh Farm Sdn Bhd',
                  date: '2026-04-14',
                  amount: '-RM 1,100',
                  amountColor: Color(0xFFEF4444),
                  icon: Icons.trending_down_rounded,
                  iconColor: Color(0xFFF87171),
                ),
                const _TransactionRow(
                  title: 'Maju Bakery Counter',
                  date: '2026-04-12',
                  amount: '+RM 8,800',
                  amountColor: Color(0xFF16A34A),
                  icon: Icons.trending_up_rounded,
                  iconColor: Color(0xFF34D399),
                ),
                const _TransactionRow(
                  title: 'Maxis Berhad',
                  date: '2026-04-10',
                  amount: '-RM 280',
                  amountColor: Color(0xFFEF4444),
                  icon: Icons.trending_down_rounded,
                  iconColor: Color(0xFFF87171),
                ),
                const _TransactionRow(
                  title: 'Tenaga Nasional Berhad',
                  date: '2026-04-08',
                  amount: '-RM 1,320',
                  amountColor: Color(0xFFEF4444),
                  icon: Icons.trending_down_rounded,
                  iconColor: Color(0xFFF87171),
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

// ─── Small reusable widgets (ALL UNCHANGED from original) ─────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 3,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TrendChartPainter(), child: const SizedBox.expand());
  }
}

class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = const Color(0xFFF1F5F9)..strokeWidth = 1;
    final paintHistorical = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paintHistoricalFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.18),
          const Color(0xFF3B82F6).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final paintForecast = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final paintZero = Paint()..color = const Color(0xFFEF4444)..strokeWidth = 1.5;

    const left = 48.0; const right = 14.0; const top = 12.0; const bottom = 30.0;
    final chartWidth  = size.width  - left - right;
    final chartHeight = size.height - top  - bottom;
    final origin = Offset(left, top + chartHeight * 0.62);

    for (var i = 0; i < 5; i++) {
      final y = top + (chartHeight / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), paintGrid);
    }
    canvas.drawLine(Offset(left, origin.dy), Offset(size.width - right, origin.dy), paintZero);

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
    for (final p in historicalPoints.skip(1)) { historicalPath.lineTo(p.dx, p.dy); }
    final areaPath = Path()
      ..addPath(historicalPath, Offset.zero)
      ..lineTo(historicalPoints.last.dx, origin.dy)
      ..lineTo(historicalPoints.first.dx, origin.dy)
      ..close();
    canvas.drawPath(areaPath, paintHistoricalFill);
    canvas.drawPath(historicalPath, paintHistorical);

    for (var i = 0; i < forecastPoints.length - 1; i++) {
      _drawDashedSegment(canvas, forecastPoints[i], forecastPoints[i + 1],
          paintForecast, dashLength: 8, gapLength: 5);
    }

    final yLabels = [
      ('RM 60k', top), ('RM 40k', top + chartHeight * 0.25),
      ('RM 20k', top + chartHeight * 0.50), ('RM 0k', top + chartHeight * 0.75),
      ('RM -20k', top + chartHeight),
    ];
    for (final l in yLabels) {
      final tp = TextPainter(
        text: TextSpan(text: l.$1, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(6, l.$2 - tp.height / 2));
    }

    final xLabels = ['24 Feb','3 Mar','10 Mar','17 Mar','24 Mar','31 Mar',
        '7 Apr','14 Apr','21 Apr','28 Apr','5 May','12 May','26 May','9 Jun'];
    for (var i = 0; i < xLabels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: xLabels[i], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = left + (chartWidth / (xLabels.length - 1)) * i - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 18));
    }
  }

  void _drawDashedSegment(Canvas canvas, Offset start, Offset end, Paint paint,
      {required double dashLength, required double gapLength}) {
    final dx = end.dx - start.dx; final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final ux = dx / distance; final uy = dy / distance;
    var traveled = 0.0;
    while (traveled < distance) {
      final de = math.min(traveled + dashLength, distance);
      canvas.drawLine(Offset(start.dx + ux * traveled, start.dy + uy * traveled),
          Offset(start.dx + ux * de, start.dy + uy * de), paint);
      traveled += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _RecommendationRow extends StatelessWidget {
  final int index; final String title; final String subtitle;
  final String amount; final String amountHint;
  final Color amountColor; final Color accent;

  const _RecommendationRow({
    required this.index, required this.title, required this.subtitle,
    required this.amount, required this.amountHint,
    required this.amountColor, required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Row(children: [
              Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(999)),
                child: const Text('easy', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amount, style: TextStyle(color: amountColor, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(amountHint, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String title; final String date; final String amount;
  final Color amountColor; final IconData icon; final Color iconColor;

  const _TransactionRow({
    required this.title, required this.date, required this.amount,
    required this.amountColor, required this.icon, required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ])),
        const SizedBox(width: 10),
        Text(amount, style: TextStyle(color: amountColor, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── _sectionRow — now accepts optional onAction callback ──────────────────────
Widget _sectionRow(
  String title,
  String subtitle, {
  String? actionText,
  VoidCallback? onAction,  // ← NEW: replaces the dead () {}
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
      if (actionText != null)
        TextButton.icon(
          onPressed: onAction, // ← calls the callback (null = button disabled gracefully)
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