import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../upload/upload_page.dart';
import '../risks/risks_page.dart';
import '../actions/recommendation_page.dart';
import '../dashboard/dashboard_page.dart';
import '../login/login_page.dart';

enum _AppSection { dashboard, upload, risks, recommendations }

class AppLayout extends StatefulWidget {
  final _AppSection initialSection;

  const AppLayout({super.key, this.initialSection = _AppSection.dashboard});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  late _AppSection _currentSection;
  String? _businessId;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection;
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final businessId = prefs.getString('business_id');
        _businessId = (businessId == null || businessId.isEmpty) ? null : businessId;
      } else {
        final home = Platform.environment['HOME'] ?? '.';
        final file = File('$home/.finsight_business_id');
        if (await file.exists()) {
          final businessId = (await file.readAsString()).trim();
          _businessId = businessId.isEmpty ? null : businessId;
        }
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingSession = false;
      });
    }
  }

  Future<void> _saveBusinessId(String businessId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_id', businessId);
    } else {
      final home = Platform.environment['HOME'] ?? '.';
      final file = File('$home/.finsight_business_id');
      await file.writeAsString(businessId);
    }
    if (!mounted) return;
    setState(() {
      _businessId = businessId;
      _currentSection = _AppSection.dashboard;
    });
  }

  void _setSection(_AppSection section, {bool closeDrawer = false}) {
    if (_currentSection == section) {
      if (closeDrawer && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {
      _currentSection = section;
    });
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  ({String title, String? subtitle, bool showAiStatus}) _pageMeta() {
    switch (_currentSection) {
      case _AppSection.dashboard:
        return (title: 'Dashboard', subtitle: null, showAiStatus: false);
      case _AppSection.upload:
        return (title: 'Upload Documents', subtitle: null, showAiStatus: true);
      case _AppSection.risks:
        return (title: 'Risk Alerts', subtitle: null, showAiStatus: false);
      case _AppSection.recommendations:
        return (title: 'Recommendations', subtitle: null, showAiStatus: false);
    }
  }

  Widget _buildCurrentPage() {
    final businessId = _businessId;
    if (businessId == null) {
      return const SizedBox.shrink();
    }

    switch (_currentSection) {
      case _AppSection.dashboard:
        return DashboardContent(
          onGoToRecommendations: () => _setSection(_AppSection.recommendations),
          onGoToRisks: () => _setSection(_AppSection.risks),
        );
      case _AppSection.upload:
        return const UploadPage(businessId: '', businessName: '');
      case _AppSection.risks:
        return RisksPage(
          businessId: businessId,
          api: RisksApi.http(baseUrl: _apiBaseUrl),
        );
      case _AppSection.recommendations:
        return RecommendationPage(businessId: businessId);
    }
  }

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

  Widget _dashboardNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.dashboard, color: Colors.white70),
      title: const Text('Dashboard', style: TextStyle(color: Colors.white70)),
      onTap: () {
        _setSection(
          _AppSection.dashboard,
          closeDrawer: Scaffold.maybeOf(context)?.isDrawerOpen ?? false,
        );
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
        _setSection(
          _AppSection.upload,
          closeDrawer: Scaffold.maybeOf(context)?.isDrawerOpen ?? false,
        );
      },
    );
  }

  Widget _riskAlertsNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_outlined, color: Colors.white70),
      title: const Text('Risk Alerts', style: TextStyle(color: Colors.white70)),
      onTap: () {
        _setSection(
          _AppSection.risks,
          closeDrawer: Scaffold.maybeOf(context)?.isDrawerOpen ?? false,
        );
      },
    );
  }

  Widget _recommendationsNavTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lightbulb_outline, color: Colors.white70),
      title: const Text(
        'Recommendations',
        style: TextStyle(color: Colors.white70),
      ),
      onTap: () {
        _setSection(
          _AppSection.recommendations,
          closeDrawer: Scaffold.maybeOf(context)?.isDrawerOpen ?? false,
        );
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
                  _dashboardNavTile(context),
                  _uploadNavTile(context),
                  _navTile(context, Icons.receipt_long, 'Transactions'),
                  _navTile(context, Icons.show_chart, 'Cash Flow Forecast'),
                  _riskAlertsNavTile(context),
                  _recommendationsNavTile(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: RiskAlertsSidebarBadge(
                businessId: _businessId!,
                api: RisksApi.http(baseUrl: _apiBaseUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final meta = _pageMeta();
    final title = meta.title;
    final subtitle = meta.subtitle;
    final showAiStatus = meta.showAiStatus;

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
                    subtitle,
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

  @override
  Widget build(BuildContext context) {
    if (_loadingSession) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_businessId == null) {
      return LoginPage(onLoginSuccess: _saveBusinessId);
    }

    final meta = _pageMeta();
    final title = meta.title;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 800;
        if (narrow) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(title: Text(title)),
            drawer: Drawer(child: _buildSidebar(context)),
            body: _buildCurrentPage(),
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
                    Expanded(child: _buildCurrentPage()),
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