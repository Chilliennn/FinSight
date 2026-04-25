import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actions/recommendation_page.dart';
import '../dashboard/dashboard_page.dart';
import '../forecast/forecast_page.dart';
import '../login/login_page.dart';
import '../risks/risks_page.dart';
import '../transaction/transaction_page.dart';
import 'settings_page.dart';
import '../upload/upload_page.dart';

enum _AppSection {
  dashboard,
  upload,
  transactions,
  forecast,
  risks,
  recommendations,
  settings,
}

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

  String _sessionFilePath() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return '$home/.finsight_business_id';
  }

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
        _businessId = (businessId == null || businessId.isEmpty)
            ? null
            : businessId;
      } else {
        final file = File(_sessionFilePath());
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
      final file = File(_sessionFilePath());
      await file.writeAsString(businessId);
    }

    if (!mounted) return;
    setState(() {
      _businessId = businessId;
      _currentSection = _AppSection.dashboard;
    });
  }

  Future<void> _clearBusinessId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('business_id');
    } else {
      final file = File(_sessionFilePath());
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) return;
    setState(() {
      _businessId = null;
      _currentSection = _AppSection.dashboard;
    });
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('You will be redirected to the login page.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _clearBusinessId();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _setSection(_AppSection section, {bool closeDrawer = false}) {
    if (_currentSection != section) {
      setState(() {
        _currentSection = section;
      });
    }

    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  ({String title, String? subtitle, bool showAiStatus}) _pageMeta() {
    switch (_currentSection) {
      case _AppSection.dashboard:
        return (title: 'Dashboard', subtitle: null, showAiStatus: false);
      case _AppSection.upload:
        return (
          title: 'Upload Documents',
          subtitle: _businessId,
          showAiStatus: true,
        );
      case _AppSection.transactions:
        return (
          title: 'Transactions',
          subtitle: _businessId,
          showAiStatus: true,
        );
      case _AppSection.forecast:
        return (
          title: 'Cash Flow Forecast',
          subtitle: null,
          showAiStatus: false,
        );
      case _AppSection.risks:
        return (title: 'Risk Alerts', subtitle: null, showAiStatus: false);
      case _AppSection.recommendations:
        return (title: 'Recommendations', subtitle: null, showAiStatus: false);
      case _AppSection.settings:
        return (title: 'Settings', subtitle: null, showAiStatus: false);
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
          onGoToTransactions: () => _setSection(_AppSection.transactions),
        );
      case _AppSection.upload:
        return UploadPage(businessId: businessId, businessName: businessId);
      case _AppSection.transactions:
        return TransactionPage(businessId: businessId);
      case _AppSection.forecast: 
        return ForecastContent(
          businessId: businessId,
          apiBaseUrl: _apiBaseUrl,
        );
      case _AppSection.risks:
        return RisksPage(
          businessId: businessId,
          api: RisksApi.http(baseUrl: _apiBaseUrl),
          onGoToRecommendations: () => _setSection(_AppSection.recommendations),
        );
      case _AppSection.recommendations:
        return RecommendationPage(businessId: businessId);
      case _AppSection.settings:
        return SettingsPage(
          apiBaseUrl: _apiBaseUrl,
          businessId: businessId,
          initialBusiness: null,
          onBusinessUpdated: (_) {},
          onConfirmLogout: () {},
        );
    }
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _AppSection section,
  }) {
    final isSelected = _currentSection == section;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF172033),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        _setSection(
          section,
          closeDrawer: Scaffold.maybeOf(context)?.isDrawerOpen ?? false,
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
    Color textColor = Colors.white70,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
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
              padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _navTile(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    section: _AppSection.dashboard,
                  ),
                  _navTile(
                    context,
                    icon: Icons.upload_file_outlined,
                    label: 'Upload Documents',
                    section: _AppSection.upload,
                  ),
                  _navTile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    section: _AppSection.transactions,
                  ),
                  _navTile(
                    context,
                    icon: Icons.show_chart_outlined,
                    label: 'Cash Flow Forecast',
                    section: _AppSection.forecast,
                  ),
                  _navTile(
                    context,
                    icon: Icons.warning_amber_outlined,
                    label: 'Risk Alerts',
                    section: _AppSection.risks,
                  ),
                  _navTile(
                    context,
                    icon: Icons.lightbulb_outline,
                    label: 'Recommendations',
                    section: _AppSection.recommendations,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  _actionTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    iconColor: const Color(0xFFFCA5A5),
                    textColor: const Color(0xFFFCA5A5),
                    onTap: _showLogoutConfirmation,
                  ),
                ],
              ),
            ),
            if (_businessId != null)
              Padding(
                padding: const EdgeInsets.all(12),
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

    return Container(
      height: subtitle == null ? 72 : 102,
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
           GestureDetector(
            onTap: () => _setSection(_AppSection.settings),
            child: const CircleAvatar(
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

    final title = _pageMeta().title;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
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

