import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  final String businessId;

  const TransactionPage({super.key, required this.businessId});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client = http.Client();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _allRows = [];
  Map<String, dynamic> _summary = const {};
  List<String> _categoryOptions = const ['All'];
  List<String> _typeOptions = const ['All', 'Inflow', 'Outflow'];
  List<String> _sourceOptions = const [
    'All',
    'Bank Statement',
    'Invoice',
    'Receipt',
  ];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedType = 'All';
  String _selectedSource = 'All';
  bool _showFilterPanel = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions(showLoading: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _loadTransactions({required bool showLoading}) async {
    if (!mounted) return;
    setState(() {
      _loading = showLoading;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/transactions/${widget.businessId}')
          .replace(
            queryParameters: {
              if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim(),
              if (_selectedCategory != 'All') 'category': _selectedCategory,
              if (_selectedType != 'All') 'type': _selectedType,
              if (_selectedSource != 'All') 'source': _selectedSource,
            },
          );

      final response = await _client
          .get(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || body['success'] != true) {
        throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
      }

      final data = (body['data'] as Map<String, dynamic>? ?? const {});
      final rawRows = (data['rows'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final options =
          (data['filter_options'] as Map<String, dynamic>? ?? const {});
      final categories =
          (options['category'] as List<dynamic>? ?? const ['All'])
              .map((item) => item.toString())
              .toList();
      final types = (options['type'] as List<dynamic>? ?? const ['All'])
          .map((item) => item.toString())
          .toList();
      final sources = (options['source'] as List<dynamic>? ?? const ['All'])
          .map((item) => item.toString())
          .toList();

      if (!mounted) return;
      setState(() {
        _rows = rawRows;
        _allRows = rawRows;
        _summary = (data['summary'] as Map<String, dynamic>? ?? const {});
        _categoryOptions = categories;
        _typeOptions = types;
        _sourceOptions = sources;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _formatAmount(double amount, {required bool positive}) {
    final formatter = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    final label = formatter.format(amount.abs());
    return positive ? '+$label' : '-$label';
  }

  String _summaryRange() {
    if (_allRows.isEmpty) {
      return '0 transactions extracted from uploaded documents';
    }
    final dates =
        _allRows
            .map((row) => DateTime.tryParse((row['txn_date'] ?? '').toString()))
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (dates.isEmpty) {
      return '${_allRows.length} transactions extracted from uploaded documents';
    }
    final first = DateFormat('MMM yyyy').format(dates.first);
    final last = DateFormat('MMM yyyy').format(dates.last);
    return '${_allRows.length} transactions extracted from uploaded documents ($first - $last)';
  }

  Future<void> _applyFilters() async {
    await _loadTransactions(showLoading: false);
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _chipGroup({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: options
          .map(
            (option) => _filterChip(
              label: option,
              selected: selected == option,
              onTap: () {
                if (selected == option) return;
                setState(() {
                  onSelected(option);
                });
                _applyFilters();
              },
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF991B1B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadTransactions(showLoading: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _rows;
    final range = _summaryRange();
    final totalInflow = (NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: 0,
    ).format(((_summary['total_inflow'] as num?) ?? 0).abs()));
    final totalOutflow = (NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: 0,
    ).format(((_summary['total_outflow'] as num?) ?? 0).abs()));
    final netAmount = ((_summary['net_amount'] as num?) ?? 0).toDouble();
    final overdueInvoices = ((_summary['overdue_invoices'] as num?) ?? 0)
        .toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1100
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Total Inflow',
                    value: '+$totalInflow',
                    valueColor: const Color(0xFF16A34A),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Total Outflow',
                    value: '-$totalOutflow',
                    valueColor: const Color(0xFFEF4444),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Net Amount',
                    value: _formatAmount(
                      netAmount.abs(),
                      positive: netAmount >= 0,
                    ),
                    valueColor: netAmount >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEF4444),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Overdue Invoices',
                    value: '$overdueInvoices',
                    valueColor: const Color(0xFFDC2626),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      setState(() => _searchQuery = value);
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () {
                          _applyFilters();
                        },
                      );
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search transactions, vendors, invoice numbers...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showFilterPanel = !_showFilterPanel;
                    });
                  },
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showFilterPanel) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CATEGORY',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _chipGroup(
                              options: _categoryOptions,
                              selected: _selectedCategory,
                              onSelected: (value) => _selectedCategory = value,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'SOURCE',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _chipGroup(
                              options: _sourceOptions,
                              selected: _selectedSource,
                              onSelected: (value) => _selectedSource = value,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TYPE',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _chipGroup(
                              options: _typeOptions,
                              selected: _selectedType,
                              onSelected: (value) => _selectedType = value,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Text(
                    'Showing ${filtered.length} of ${_summary['total_transactions'] ?? filtered.length} transactions',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 110,
                        child: Text('DATE', style: _TableHeaderStyle.style),
                      ),
                      SizedBox(
                        width: 210,
                        child: Text(
                          'DESCRIPTION',
                          style: _TableHeaderStyle.style,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: Text('VENDOR', style: _TableHeaderStyle.style),
                      ),
                      SizedBox(
                        width: 130,
                        child: Text('CATEGORY', style: _TableHeaderStyle.style),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text('AMOUNT', style: _TableHeaderStyle.style),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text('STATUS', style: _TableHeaderStyle.style),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text('SOURCE', style: _TableHeaderStyle.style),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No transactions match your search.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (transaction) => _TransactionRow(transaction: transaction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderStyle {
  static const TextStyle style = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF94A3B8),
    letterSpacing: 0.3,
  );
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionRow({required this.transaction});

  bool get _isInflow => (transaction['type'] ?? 'Inflow') == 'Inflow';

  Color get _amountColor =>
      _isInflow ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

  IconData get _icon =>
      _isInflow ? Icons.trending_up_rounded : Icons.trending_down_rounded;

  Color get _iconColor =>
      _isInflow ? const Color(0xFF34D399) : const Color(0xFFF87171);

  String get _status => (transaction['status'] ?? 'Pending').toString();

  String _amountLabel() {
    final amount = ((transaction['amount'] as num?) ?? 0).toDouble().abs();
    final formatter = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return _isInflow
        ? '+${formatter.format(amount)}'
        : '-${formatter.format(amount)}';
  }

  Color get _chipColor {
    return switch (_status) {
      'Paid' => const Color(0xFF10B981),
      'Overdue' => const Color(0xFFDC2626),
      _ => const Color(0xFFF59E0B),
    };
  }

  Color get _chipBgColor {
    return switch (_status) {
      'Paid' => const Color(0xFFF0FDF4),
      'Overdue' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFFFFBEB),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              DateTime.tryParse(
                    (transaction['txn_date'] ?? '').toString(),
                  )?.toIso8601String().substring(0, 10) ??
                  '-',
              style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
            ),
          ),
          SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (transaction['description'] ?? 'Transaction').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (transaction['document_id'] ??
                          transaction['category'] ??
                          transaction['type'] ??
                          '-')
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              (transaction['vendor_name'] ?? '-').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          SizedBox(
            width: 130,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                (transaction['category'] ?? transaction['type'] ?? '-')
                    .toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              _amountLabel(),
              style: TextStyle(
                color: _amountColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _chipBgColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _chipColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, size: 14, color: _iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (transaction['source'] ?? '-').toString(),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
