import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'transaction_model.dart';
import 'transaction_repository.dart';

enum _TransactionFilter { all, paid, pending, overdue, income, expense }

class TransactionPage extends StatefulWidget {
  final String businessId;

  const TransactionPage({super.key, required this.businessId});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final TransactionRepository _repo = TransactionRepository();
  final TextEditingController _searchController = TextEditingController();

  List<TransactionRecord> _transactions = [];
  String _searchQuery = '';
  _TransactionFilter _filter = _TransactionFilter.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transactions = await _repo.fetchTransactions(widget.businessId);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
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

  List<TransactionRecord> get _filteredTransactions {
    return _transactions.where((transaction) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          [
            transaction.displayTitle,
            transaction.secondaryLabel,
            transaction.category ?? '',
            transaction.type,
            transaction.statusLabel,
            transaction.sourceLabel,
            transaction.amountLabel,
            DateFormat('yyyy-MM-dd').format(transaction.txnDate),
          ].join(' ').toLowerCase().contains(query);

      final matchesFilter = switch (_filter) {
        _TransactionFilter.all => true,
        _TransactionFilter.paid => transaction.isPaid,
        _TransactionFilter.pending =>
          !transaction.isPaid && !transaction.isOverdue,
        _TransactionFilter.overdue => transaction.isOverdue,
        _TransactionFilter.income => transaction.isCredit,
        _TransactionFilter.expense => !transaction.isCredit,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  double get _totalInflow => _transactions
      .where((transaction) => transaction.isCredit)
      .fold(0, (sum, transaction) => sum + transaction.amount.abs());

  double get _totalOutflow => _transactions
      .where((transaction) => !transaction.isCredit)
      .fold(0, (sum, transaction) => sum + transaction.amount.abs());

  int get _overdueCount =>
      _transactions.where((transaction) => transaction.isOverdue).length;

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
    if (_transactions.isEmpty) {
      return '0 transactions extracted from uploaded documents';
    }
    final dates =
        _transactions.map((transaction) => transaction.txnDate).toList()
          ..sort();
    final first = DateFormat('MMM yyyy').format(dates.first);
    final last = DateFormat('MMM yyyy').format(dates.last);
    return '${_transactions.length} transactions extracted from uploaded documents ($first - $last)';
  }

  Future<void> _chooseFilter() async {
    final selected = await showModalBottomSheet<_TransactionFilter>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in _TransactionFilter.values)
                RadioListTile<_TransactionFilter>(
                  value: option,
                  groupValue: _filter,
                  onChanged: (value) => Navigator.of(context).pop(value),
                  title: Text(_filterLabel(option)),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _filter = selected);
    }
  }

  String _filterLabel(_TransactionFilter filter) {
    return switch (filter) {
      _TransactionFilter.all => 'All',
      _TransactionFilter.paid => 'Paid',
      _TransactionFilter.pending => 'Pending',
      _TransactionFilter.overdue => 'Overdue',
      _TransactionFilter.income => 'Income',
      _TransactionFilter.expense => 'Expense',
    };
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
                onPressed: _loadTransactions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredTransactions;
    final range = _summaryRange();

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
                    value: _formatAmount(_totalInflow, positive: true),
                    valueColor: const Color(0xFF16A34A),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Total Outflow',
                    value: _formatAmount(_totalOutflow, positive: false),
                    valueColor: const Color(0xFFEF4444),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Total Transactions',
                    value: '${_transactions.length}',
                    valueColor: const Color(0xFF0F172A),
                  ),
                  _SummaryCard(
                    width: cardWidth,
                    label: 'Overdue Invoices',
                    value: '$_overdueCount',
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
                    onChanged: (value) => setState(() => _searchQuery = value),
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
                  onPressed: _chooseFilter,
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(_filterLabel(_filter)),
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
                    'Showing ${filtered.length} of ${_transactions.length} transactions',
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
  final TransactionRecord transaction;

  const _TransactionRow({required this.transaction});

  Color get _amountColor =>
      transaction.isCredit ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

  IconData get _icon => transaction.isCredit
      ? Icons.trending_up_rounded
      : Icons.trending_down_rounded;

  Color get _iconColor =>
      transaction.isCredit ? const Color(0xFF34D399) : const Color(0xFFF87171);

  Color get _chipColor {
    return switch (transaction.statusLabel) {
      'Paid' => const Color(0xFF10B981),
      'Overdue' => const Color(0xFFDC2626),
      _ => const Color(0xFFF59E0B),
    };
  }

  Color get _chipBgColor {
    return switch (transaction.statusLabel) {
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
              DateFormat('yyyy-MM-dd').format(transaction.txnDate),
              style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
            ),
          ),
          SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayTitle,
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
                  transaction.secondaryLabel,
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
              transaction.vendorName?.trim().isNotEmpty == true
                  ? transaction.vendorName!
                  : '-',
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
                transaction.category?.trim().isNotEmpty == true
                    ? transaction.category!
                    : transaction.type,
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
              transaction.amountLabel,
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
                transaction.statusLabel,
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
                    transaction.sourceLabel,
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
