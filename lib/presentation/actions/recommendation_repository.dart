// lib/presentation/actions/recommendation_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'recommendation_model.dart';

class RecommendationRepository {
  static const String _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client;
  RecommendationRepository({http.Client? client}) : _client = client ?? http.Client();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  // Unwraps { success, data, error } envelope — throws on failure
  Map<String, dynamic> _unwrap(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception('[${res.statusCode}] ${body['error'] ?? 'Unknown error'}');
    }
    final data = body['data'];
    if (data == null) throw Exception('Envelope missing "data"');
    return data as Map<String, dynamic>;
  }

  // Parses { summary, recommendations } shape
  Map<String, dynamic> _parseList(Map<String, dynamic> data) => {
        'summary':         RecommendationSummary.fromJson(data['summary'] as Map<String, dynamic>),
        'recommendations': (data['recommendations'] as List<dynamic>)
            .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
            .toList(),
      };

  Future<Map<String, dynamic>> fetchRecommendations(String businessId) async {
    final res = await _client
        .get(Uri.parse('$_base/api/recommendations/$businessId'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _parseList(_unwrap(res));
  }

  Future<Map<String, dynamic>> generateFromTransactions({
    required String businessId,
    required String riskId,
    required String businessName,
    required String businessType,
    required double currentBalance,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_base/api/recommendations/generate'),
          headers: _headers,
          body: jsonEncode({
            'businessId':     businessId,
            'riskId':         riskId,
            'businessName':   businessName,
            'businessType':   businessType,
            'currentBalance': currentBalance,
          }),
        )
        .timeout(const Duration(seconds: 120));
    return _parseList(_unwrap(res));
  }

  Future<Recommendation> markActioned(String id) async {
    final res = await _client
        .patch(Uri.parse('$_base/api/recommendations/$id/action'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return Recommendation.fromJson(_unwrap(res));
  }
}