// lib/presentation/shared/app_layout.dart
//
// Changes from previous version (document 9):
//   1. Added _dashboardNavTile() — same pattern as zh's _riskAlertsNavTile.
//      Dashboard tile now navigates back to dashboard instead of showing SnackBar.
//   2. DashboardContent now receives onGoToRecommendations + onGoToRisks callbacks.
//      This is how the dashboard's "View all 5" and "View Risks" buttons work
//      without dashboard_page.dart needing to import app_layout.dart (no circular dep).
//   3. import for dashboard_page.dart added.
//   4. All other code (zh's tiles, _navTile, _buildTopBar, build) is UNCHANGED.

import 'package:flutter/material.dart';
import '../upload/upload_page.dart';
import '../risks/risks_page.dart';         // zh's risk navigation
import '../actions/recommendation_page.dart';     // xy's recommendations navigation
import '../dashboard/dashboard_page.dart'; // ← NEW: for dashboard tile + callbacks

class AppLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  final bool showAiStatus;

  const AppLayout({
    super.key,
    required this.child,
    this.title = 'FinSight',
    this.subtitle,
    this.showAiStatus = false,
  });

  // ── Original _navTile — UNTOUCHED ─────────────────────────────────────────
  Widget _navTile(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label tapped')));
      },
    );
  }

  // ── NEW: Dashboard nav tile ───────────────────────────────────────────────
  // Navigates back to Dashboard. Uses popUntil so it works whether we got here
  // via push (from dashboard) or are already at root.
  Widget _dashboardNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.dashboard, color: Colors.white70),
      title: const Text('Dashboard', style: TextStyle(color: Colors.white70)),
      onTap: () {
        // Pop back to the first route (Dashboard is always the root).
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  Widget _uploadNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.upload_file, color: Colors.white70),
      title: const Text(
        'Upload Documents',
        style: TextStyle(color: Colors.white70),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AppLayout(
              title: 'Upload Documents',
              showAiStatus: true,
              child: UploadPage(),
            ),
          ),
        );
      },
    );
  }

  // ── zh's Risk Alerts tile — UNTOUCHED ─────────────────────────────────────
  Widget _riskAlertsNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_outlined, color: Colors.white70),
      title: const Text('Risk Alerts', style: TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppLayout(
              title: 'Risk Alerts',
              child: RisksPage(
                businessId: 'maju-bakery-demo',
                api: RisksApi.http(baseUrl: 'http://localhost:3000'),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Recommendations nav tile — UNTOUCHED ──────────────────────────────────
  Widget _recommendationsNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lightbulb_outline, color: Colors.white70),
      title: const Text(
        'Recommendations',
        style: TextStyle(color: Colors.white70),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AppLayout(
              title: 'Recommendations',
              child: RecommendationPage(
                businessId:   'demo-maju-bakery-001',
                businessName: 'Maju Bakery & Cafe',
                riskId:       'demo-risk-cashgap-001',
              ),
            ),
          ),
        );
      },
    );
  }

  // ── _buildSidebar — Dashboard tile replaced, everything else unchanged ─────
  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1220),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  CircleAvatar(child: Icon(Icons.pie_chart)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FinSight AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                children: [
                  _dashboardNavTile(context),        // ← NEW (replaces SnackBar _navTile)
                  _uploadNavTile(context),
                  _navTile(context, Icons.receipt_long, 'Transactions'),
                  _navTile(context, Icons.show_chart,   'Cash Flow Forecast'),
                  _riskAlertsNavTile(context),       // zh's tile — unchanged
                  _recommendationsNavTile(context),  // xy's tile — unchanged
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: RiskAlertsSidebarBadge(
                businessId: 'maju-bakery-demo',
                api: RisksApi.http(baseUrl: 'http://localhost:3000'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── _buildTopBar — UNTOUCHED ──────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    if (subtitle == null && !showAiStatus) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.notifications_none),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Text('MJ'),
            ),
          ],
        ),
      );
    }

    return Container(
      height: subtitle == null ? 64 : 102,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF020817),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0xFF74819A),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showAiStatus) ...[
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 11, color: Color(0xFF6EE7B7)),
                  SizedBox(width: 12),
                  Text(
                    'AI Active',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 26),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none,
                color: Color(0xFF64748B),
                size: 29,
              ),
              if (showAiStatus)
                Positioned(
                  right: -1,
                  top: -4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF4F46E5),
            child: Text(
              'MJ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── build — UNTOUCHED ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 800;
        if (narrow) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(title: Text(title)),
            drawer: Drawer(child: _buildSidebar(context)),
            body: child,
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: Row(
            children: [
              SizedBox(width: 260, child: _buildSidebar(context)),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper to build the Dashboard route with navigation callbacks ─────────────
// Call this from main.dart as the initial route's body.
// Keeps DashboardContent free of AppLayout imports (no circular dependency).
Widget buildDashboardWithNav(BuildContext context) {
  return DashboardContent(
    onGoToRecommendations: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AppLayout(
            title: 'Recommendations',
            child: RecommendationPage(
              businessId:   'demo-maju-bakery-001',
              businessName: 'Maju Bakery & Cafe',
              riskId:       'demo-risk-cashgap-001',
            ),
          ),
        ),
      );
    },
    onGoToRisks: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppLayout(
            title: 'Risk Alerts',
            child: RisksPage(
              businessId: 'maju-bakery-demo',
              api: RisksApi.http(baseUrl: 'http://localhost:3000'),
            ),
          ),
        ),
      );
    },
  );
}
