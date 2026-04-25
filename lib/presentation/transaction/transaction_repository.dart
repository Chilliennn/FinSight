import 'dart:convert';

import 'package:http/http.dart' as http;

import 'transaction_model.dart';

class TransactionRepository {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client;

  TransactionRepository({http.Client? client})
    : _client = client ?? http.Client();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _unwrap(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || decoded['success'] != true) {
      throw Exception(
        decoded['error'] ?? 'Server error ${response.statusCode}',
      );
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Response missing data');
  }

  Future<List<TransactionRecord>> fetchTransactions(String businessId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/api/transactions/$businessId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    final data = _unwrap(response);
    final rawList = (data['transactions'] as List<dynamic>? ?? const []);
    return rawList
        .map((item) => TransactionRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
