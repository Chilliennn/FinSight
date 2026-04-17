import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const AppLayout({Key? key, required this.child, this.title = 'FinSight'})
    : super(key: key);

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
                  _navTile(
                    context,
                    Icons.warning_amber_outlined,
                    'Risk Alerts',
                  ),
                  _navTile(context, Icons.lightbulb, 'Recommendations'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo Mode',
                      style: TextStyle(color: Colors.white54),
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
            appBar: AppBar(title: Text(title)),
            drawer: Drawer(child: _buildSidebar(context)),
            body: child,
          );
        }

        return Scaffold(
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
