import 'package:intl/intl.dart';

class TransactionRecord {
  final String id;
  final String businessId;
  final String? documentId;
  final double amount;
  final String type;
  final String? category;
  final DateTime txnDate;
  final String? vendorName;
  final bool isRecurring;
  final DateTime? dueDate;
  final bool isPaid;

  const TransactionRecord({
    required this.id,
    required this.businessId,
    required this.amount,
    required this.type,
    required this.txnDate,
    this.documentId,
    this.category,
    this.vendorName,
    this.isRecurring = false,
    this.dueDate,
    this.isPaid = false,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return TransactionRecord(
      id: (json['_id'] ?? '').toString(),
      businessId: (json['business_id'] ?? '').toString(),
      documentId: json['document_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: (json['type'] ?? '').toString(),
      category: json['category']?.toString(),
      txnDate: parseDate(json['txn_date']) ?? DateTime.now(),
      vendorName: json['vendor_name']?.toString(),
      isRecurring: json['is_recurring'] == true,
      dueDate: parseDate(json['due_date']),
      isPaid: json['is_paid'] == true,
    );
  }

  bool get isCredit => type.toLowerCase() != 'debit';

  bool get isOverdue {
    final due = dueDate;
    return !isPaid && due != null && due.isBefore(DateTime.now());
  }

  double get signedAmount => isCredit ? amount.abs() : -amount.abs();

  String get displayTitle => vendorName?.trim().isNotEmpty == true
      ? vendorName!.trim()
      : (category?.trim().isNotEmpty == true
            ? category!.trim()
            : 'Transaction');

  String get secondaryLabel {
    final docId = documentId?.trim();
    if (docId != null && docId.isNotEmpty) {
      return docId;
    }
    return category?.trim().isNotEmpty == true ? category!.trim() : type;
  }

  String get statusLabel {
    if (isPaid) return 'Paid';
    if (isOverdue) return 'Overdue';
    return 'Pending';
  }

  String get sourceLabel {
    if (!isPaid) return 'Invoice';
    return isCredit ? 'Bank' : 'Receipt';
  }

  String get amountLabel {
    final formatter = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    final value = formatter.format(amount.abs());
    return isCredit ? '+$value' : '-$value';
  }
}
