// lib/data/repositories/recommendation_repository.dart


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation_model.dart';

class RecommendationRepository {
  
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client;

  RecommendationRepository({http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      };

  // ── Envelope parser ───────────────────────────────────────────────────────

  Map<String, dynamic> _parseEnvelope(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Server returned non-JSON (HTTP ${response.statusCode}): '
        '${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
    }

    if (response.statusCode >= 400 || body['success'] != true) {
      final serverError = body['error'] as String? ?? 'Unknown server error';
      throw Exception('[${response.statusCode}] $serverError');
    }

    final data = body['data'];
    if (data == null) throw Exception('Envelope missing "data" field');
    return data as Map<String, dynamic>;
  }

  // ── Payload parser ────────────────────────────────────────────────────────

  Map<String, dynamic> _parseRecommendationPayload(Map<String, dynamic> data) {
    return {
      'summary': RecommendationSummary.fromJson(
          data['summary'] as Map<String, dynamic>),
      'recommendations': (data['recommendations'] as List<dynamic>)
          .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
          .toList(),
    };
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetch all active, non-expired recommendations for [businessId].
  /// Returns { summary: RecommendationSummary, recommendations: List<Recommendation> }
  Future<Map<String, dynamic>> fetchRecommendations(String businessId) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/$businessId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parseRecommendationPayload(_parseEnvelope(response));
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('fetchRecommendations: $err');
    }
  }

  /// Fetch a single recommendation by [id].
  Future<Recommendation> fetchById(String id) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/item/$id');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseEnvelope(response));
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('fetchById: $err');
    }
  }

  /// Trigger AI to generate fresh recommendations from [financialSnapshot].
  /// Returns { summary: RecommendationSummary, recommendations: List<Recommendation> }
  Future<Map<String, dynamic>> generateRecommendations({
    required String businessId,
    required String riskId,
    required Map<String, dynamic> financialSnapshot,
  }) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/generate');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'businessId':        businessId,
              'riskId':            riskId,
              'financialSnapshot': financialSnapshot,
            }),
          )
          .timeout(const Duration(seconds: 120));
      return _parseRecommendationPayload(_parseEnvelope(response));
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('generateRecommendations: $err');
    }
  }

  /// Mark a recommendation as actioned.
  Future<Recommendation> markActioned(String id) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/$id/action');
      final response = await _client
          .patch(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseEnvelope(response));
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('markActioned: $err');
    }
  }

  /// Partially update a recommendation (e.g. dismiss).
  Future<Recommendation> updateRecommendation(
      String id, Map<String, dynamic> fields) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/$id');
      final response = await _client
          .patch(uri, headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseEnvelope(response));
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('updateRecommendation: $err');
    }
  }

  /// Hard-delete a recommendation by [id].
  Future<void> deleteRecommendation(String id) async {
    try {
      final uri      = Uri.parse('$_baseUrl/api/recommendations/$id');
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      _parseEnvelope(response);
    } on Exception {
      rethrow;
    } catch (err) {
      throw Exception('deleteRecommendation: $err');
    }
  }
}