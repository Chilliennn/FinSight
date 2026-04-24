// lib/presentation/actions/services/recommendation_service.dart
//
// All HTTP communication with the Node.js backend.
// Widgets NEVER import http directly — they call this service only.
//
// ── MOCK MODE ────────────────────────────────────────────────────────────────
// Set _useMock = true  → returns hardcoded demo data instantly (no backend needed)
// Set _useMock = false → calls http://localhost:3000 (requires backend running)
//
// Switch back to false once your Node.js server is running.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation_model.dart';

class RecommendationService {
  // ── Toggle this ───────────────────────────────────────────────────────────
  static const bool _useMock = true; // ← change to false when backend is ready
  // ─────────────────────────────────────────────────────────────────────────

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client;

  RecommendationService({http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Map<String, dynamic> _parseBody(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  // ── fetchRecommendations ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchRecommendations(String businessId) async {
    if (_useMock) return _mockFetchRecommendations();

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/$businessId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      final data = _parseBody(response);
      return {
        'summary': RecommendationSummary.fromJson(
            data['summary'] as Map<String, dynamic>),
        'recommendations': (data['recommendations'] as List<dynamic>)
            .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
            .toList(),
      };
    } catch (err) {
      throw Exception('fetchRecommendations: $err');
    }
  }

  // ── fetchById ─────────────────────────────────────────────────────────────

  Future<Recommendation> fetchById(String id) async {
    if (_useMock) {
      final result = await _mockFetchRecommendations();
      final list = result['recommendations'] as List<Recommendation>;
      return list.firstWhere((r) => r.id == id, orElse: () => list.first);
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/item/$id');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseBody(response));
    } catch (err) {
      throw Exception('fetchById: $err');
    }
  }

  // ── generateRecommendations ───────────────────────────────────────────────

  Future<Map<String, dynamic>> generateRecommendations({
    required String businessId,
    required String riskId,
    required Map<String, dynamic> financialSnapshot,
  }) async {
    if (_useMock) return _mockFetchRecommendations();

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/generate');
      final response = await _client
          .post(uri,
              headers: _headers,
              body: jsonEncode({
                'businessId': businessId,
                'riskId': riskId,
                'financialSnapshot': financialSnapshot,
              }))
          .timeout(const Duration(seconds: 90));
      final data = _parseBody(response);
      return {
        'summary': RecommendationSummary.fromJson(
            data['summary'] as Map<String, dynamic>),
        'recommendations': (data['recommendations'] as List<dynamic>)
            .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
            .toList(),
      };
    } catch (err) {
      throw Exception('generateRecommendations: $err');
    }
  }

  // ── markActioned ──────────────────────────────────────────────────────────

  Future<Recommendation> markActioned(String id) async {
    if (_useMock) return _mockMarkActioned(id);

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/$id/action');
      final response = await _client
          .patch(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseBody(response));
    } catch (err) {
      throw Exception('markActioned: $err');
    }
  }

  // ── updateRecommendation ──────────────────────────────────────────────────

  Future<Recommendation> updateRecommendation(
      String id, Map<String, dynamic> fields) async {
    if (_useMock) return fetchById(id);

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/$id');
      final response = await _client
          .patch(uri, headers: _headers, body: jsonEncode(fields))
          .timeout(const Duration(seconds: 15));
      return Recommendation.fromJson(_parseBody(response));
    } catch (err) {
      throw Exception('updateRecommendation: $err');
    }
  }

  // ── deleteRecommendation ──────────────────────────────────────────────────

  Future<void> deleteRecommendation(String id) async {
    if (_useMock) return; // no-op in mock mode

    try {
      final uri = Uri.parse('$_baseUrl/api/recommendations/$id');
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      _parseBody(response);
    } catch (err) {
      throw Exception('deleteRecommendation: $err');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MOCK DATA — matches the FinSight AI mockup screens exactly
  // (Maju Bakery & Cafe, 16 Apr 2026)
  // ═════════════════════════════════════════════════════════════════════════

  static final _now       = DateTime(2026, 4, 16, 8, 0);
  static final _expiresAt = DateTime(2026, 4, 23, 8, 0);

  static final List<Recommendation> _mockRecs = [
    Recommendation(
      id:                   'mock-rec-001',
      businessId:           'demo-maju-bakery-001',
      riskId:               'demo-risk-cashgap-001',
      rank:                 1,
      category:             'Collections',
      difficulty:           'Easy Action',
      timeframe:            'Within 7 days',
      actionTitle:          'Collect Overdue Invoice from TechCorp (INV-2026-089)',
      actionPlan:           'Immediate follow-up call + formal demand letter to TechCorp Malaysia',
      reasoning:
          'Invoice INV-2026-089 is 39 days overdue (payment terms: 30 days). '
          'TechCorp Malaysia is a repeat client with good payment history — this '
          'is likely an administrative oversight. A direct follow-up has high '
          'probability of immediate payment, which would directly reduce your '
          'cash gap risk by RM 8,500.',
      projectedImpactValue: 8500,
      impactType:           'Cash Inflow',
      actionSteps: const [
        ActionStep(stepNumber: 1, description: 'Call TechCorp accounts payable (contact: Puan Azlinda, 03-2xxx-xxxx)'),
        ActionStep(stepNumber: 2, description: 'Send formal payment reminder email with invoice copy attached'),
        ActionStep(stepNumber: 3, description: 'Offer early payment discount of 1% if paid within 3 days'),
        ActionStep(stepNumber: 4, description: 'If no response in 48 hours, escalate to your account manager'),
      ],
      relatedReference:     'INV-2026-089',
      status:               'active',
      generatedAt:          _now,
      expiresAt:            _expiresAt,
    ),
    Recommendation(
      id:                   'mock-rec-002',
      businessId:           'demo-maju-bakery-001',
      riskId:               'demo-risk-cashgap-001',
      rank:                 2,
      category:             'Supplier Management',
      difficulty:           'Medium Action',
      timeframe:            'Within 2 weeks',
      actionTitle:          'Negotiate 14-Day Extension with Sunrise Ingredients',
      actionPlan:           'Request to defer annual supplier payment from 26 May to 9 June 2026',
      reasoning:
          'Sunrise Ingredients annual payment of RM 12,000 falls on 26 May, '
          'directly within your projected cash gap window. Deferring by 14 days '
          'aligns it after your expected invoice collections, eliminating the '
          'gap entirely without requiring external financing.',
      projectedImpactValue: 12000,
      impactType:           'Cash Buffer',
      actionSteps: const [
        ActionStep(stepNumber: 1, description: 'Email Sunrise Ingredients account manager requesting 14-day payment extension'),
        ActionStep(stepNumber: 2, description: 'Reference your 3-year relationship and consistent payment history'),
        ActionStep(stepNumber: 3, description: 'Offer to pay a small early-settlement fee (e.g. RM 200) as goodwill'),
        ActionStep(stepNumber: 4, description: 'Get written confirmation of new due date before 10 May'),
      ],
      relatedReference:     null,
      status:               'actioned',
      actionedAt:           DateTime(2026, 4, 16, 10, 30),
      generatedAt:          _now,
      expiresAt:            _expiresAt,
    ),
    Recommendation(
      id:                   'mock-rec-003',
      businessId:           'demo-maju-bakery-001',
      riskId:               'demo-risk-cashgap-001',
      rank:                 3,
      category:             'Collections',
      difficulty:           'Easy Action',
      timeframe:            'Within 10 days',
      actionTitle:          'Follow Up on Axiata Invoice (INV-2026-112)',
      actionPlan:           'Contact Axiata accounts payable for INV-2026-112 settlement',
      reasoning:
          'INV-2026-112 for RM 5,500 has been outstanding for 22 days against '
          'a 30-day term. Proactive follow-up now prevents it from becoming '
          'overdue and secures this cash before the May gap period.',
      projectedImpactValue: 5500,
      impactType:           'Cash Inflow',
      actionSteps: const [
        ActionStep(stepNumber: 1, description: 'Call Axiata procurement to confirm receipt of invoice'),
        ActionStep(stepNumber: 2, description: 'Request payment processing timeline confirmation'),
        ActionStep(stepNumber: 3, description: 'Send WhatsApp follow-up to your Axiata contact if no response in 2 days'),
      ],
      relatedReference:     'INV-2026-112',
      status:               'active',
      generatedAt:          _now,
      expiresAt:            _expiresAt,
    ),
    Recommendation(
      id:                   'mock-rec-004',
      businessId:           'demo-maju-bakery-001',
      riskId:               'demo-risk-cashgap-001',
      rank:                 4,
      category:             'Cost Optimization',
      difficulty:           'Easy Action',
      timeframe:            'Starting next week',
      actionTitle:          'Reduce Marketing Spend by 20% for 8 Weeks',
      actionPlan:           'Pause or reduce paid social media advertising temporarily',
      reasoning:
          'Your current RM 2,625/month paid social spend shows diminishing '
          'returns over the past 6 weeks (cost-per-lead up 34%). Reducing by '
          '20% for 8 weeks saves RM 2,100 with minimal revenue impact during '
          'a non-peak period.',
      projectedImpactValue: 2100,
      impactType:           'Cost Savings',
      actionSteps: const [
        ActionStep(stepNumber: 1, description: 'Pause lowest-performing ad sets in Meta Ads Manager'),
        ActionStep(stepNumber: 2, description: 'Reduce daily budget on remaining campaigns by 20%'),
        ActionStep(stepNumber: 3, description: 'Monitor engagement weekly — restore budget if leads drop >15%'),
      ],
      relatedReference:     null,
      status:               'active',
      generatedAt:          _now,
      expiresAt:            _expiresAt,
    ),
    Recommendation(
      id:                   'mock-rec-005',
      businessId:           'demo-maju-bakery-001',
      riskId:               'demo-risk-cashgap-001',
      rank:                 5,
      category:             'Financing',
      difficulty:           'Medium Action',
      timeframe:            '2-4 weeks processing',
      actionTitle:          'Apply for SME BizMaju Micro Financing',
      actionPlan:           'Submit application to SME Bank for Micro Financing up to RM 50,000',
      reasoning:
          "As a precautionary measure, applying for SME Bank's BizMaju Micro "
          'Financing provides a credit line buffer. Interest rate is 4-6% per '
          'annum. Even if you resolve the cash gap through collections, having '
          'an approved credit facility provides security for future seasonal '
          'dips. Application requires 12-month bank statements (which you now '
          'have structured).',
      projectedImpactValue: 50000,
      impactType:           'Available Financing',
      actionSteps: const [
        ActionStep(stepNumber: 1, description: 'Prepare documents: 12-month bank statements, last 2 years financial statements'),
        ActionStep(stepNumber: 2, description: 'Visit SME Bank branch at Jalan Raja Chulan, KL (or apply online at smebank.com.my)'),
        ActionStep(stepNumber: 3, description: 'Submit BizMaju Micro Financing application (max RM 50,000, up to 5 years)'),
        ActionStep(stepNumber: 4, description: 'Processing time: 2-4 weeks for approval'),
      ],
      relatedReference:     null,
      status:               'actioned',
      actionedAt:           DateTime(2026, 4, 16, 14, 0),
      generatedAt:          _now,
      expiresAt:            _expiresAt,
    ),
  ];

  // Mutable local copy so markActioned updates are reflected instantly in UI
  static final List<Recommendation> _mutableMockRecs =
      List<Recommendation>.from(_mockRecs);

  Future<Map<String, dynamic>> _mockFetchRecommendations() async {
    // Simulate a brief network delay so loading spinner is visible
    await Future.delayed(const Duration(milliseconds: 400));

    final active = _mutableMockRecs
        .where((r) => r.status != 'expired')
        .toList();

    final nonFinancing = active
        .where((r) => r.impactType != 'Available Financing')
        .toList();

    final totalImpact = nonFinancing.fold<double>(
        0, (sum, r) => sum + r.projectedImpactValue);
    final cashInflow  = nonFinancing
        .where((r) => r.impactType == 'Cash Inflow')
        .fold<double>(0, (s, r) => s + r.projectedImpactValue);
    final cashBuffer  = nonFinancing
        .where((r) => r.impactType == 'Cash Buffer')
        .fold<double>(0, (s, r) => s + r.projectedImpactValue);
    final costSavings = nonFinancing
        .where((r) => r.impactType == 'Cost Savings')
        .fold<double>(0, (s, r) => s + r.projectedImpactValue);

    final summary = RecommendationSummary(
      totalActionableImpact: totalImpact,
      cashInflow:            cashInflow,
      cashBuffer:            cashBuffer,
      costSavings:           costSavings,
      easyActions:   active.where((r) => r.difficulty == 'Easy Action').length,
      totalRecommendations: active.length,
      canActToday:   active.where((r) {
        final tf = r.timeframe.toLowerCase();
        return tf.contains('today') ||
               tf.contains('7 days') ||
               (tf.contains('week') && !tf.contains('2 week') && !tf.contains('2-'));
      }).length,
      impactBreakdown: active.map((r) => {
        'rank':                  r.rank,
        'projected_impact_value': r.projectedImpactValue,
        'impact_type':            r.impactType,
      }).toList(),
    );

    return {'summary': summary, 'recommendations': active};
  }

  Future<Recommendation> _mockMarkActioned(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _mutableMockRecs.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Recommendation $id not found');
    final updated = _mutableMockRecs[idx].copyWith(
      status:     'actioned',
      actionedAt: DateTime.now(),
    );
    _mutableMockRecs[idx] = updated;
    return updated;
  }
}