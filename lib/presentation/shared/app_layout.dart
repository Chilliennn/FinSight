import 'package:flutter/material.dart';
import '../risks/risks_page.dart'; // ← added by zh for Risk Alerts navigation

class AppLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const AppLayout({super.key, required this.child, this.title = 'FinSight'});

  Widget _navTile(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label tapped')));
      },
    );
  }

  // ↓↓↓ Added by zh — dedicated nav tile that navigates to Risks page.
  // Kept as a separate function so teammates' _navTile stays untouched.
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
                // Real backend. Requires `node lib/app.js` running on port 3000.
                api: RisksApi.http(baseUrl: 'http://localhost:3000'),
              ),
            ),
          ),
        );
      },
    );
  }
  // ↑↑↑ End zh addition

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
                  _navTile(context, Icons.dashboard, 'Dashboard'),
                  _navTile(context, Icons.upload_file, 'Upload Documents'),
                  _navTile(context, Icons.receipt_long, 'Transactions'),
                  _navTile(context, Icons.show_chart, 'Cash Flow Forecast'),
                  _riskAlertsNavTile(context), // ← changed by zh (was _navTile)
                  _navTile(context, Icons.lightbulb, 'Recommendations'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              // ↓↓↓ Changed by zh — was a static "Demo Mode" label.
              // Now shows real-time Active Risks count + last update time
              // from the same /api/risks backend the Risk Alerts page uses.
              child: RiskAlertsSidebarBadge(
                businessId: 'maju-bakery-demo',
                api: RisksApi.http(baseUrl: 'http://localhost:3000'),
              ),
              // ↑↑↑ End zh change
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
