// lib/presentation/actions/models/recommendation_model.dart
//
// Field names mirror the MongoDB schema exactly:
//   action_title, action_plan, reasoning, projected_impact_value,
//   impact_type, category, difficulty, timeframe, rank, action_steps,
//   related_reference, risk_id, status, actioned_at, generated_at, expires_at

class ActionStep {
  final int stepNumber;
  final String description;

  const ActionStep({
    required this.stepNumber,
    required this.description,
  });

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    return ActionStep(
      stepNumber:  (json['step_number']  as num).toInt(),
      description:  json['description']  as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'step_number': stepNumber,
    'description': description,
  };
}

class Recommendation {
  final String   id;
  final String   businessId;
  final String   riskId;
  final int      rank;
  final String   category;
  final String   difficulty;
  final String   timeframe;
  final String   actionTitle;       // action_title
  final String   actionPlan;        // action_plan
  final String   reasoning;            // DB field: reasoning
  final double   projectedImpactValue; // DB field: projected_impact_value
  final String   impactType;
  final List<ActionStep> actionSteps;
  final String?  relatedReference;
  final String   status;            // 'active' | 'actioned' | 'dismissed' | 'expired'
  final DateTime? actionedAt;
  final DateTime generatedAt;
  final DateTime expiresAt;

  const Recommendation({
    required this.id,
    required this.businessId,
    required this.riskId,
    required this.rank,
    required this.category,
    required this.difficulty,
    required this.timeframe,
    required this.actionTitle,
    required this.actionPlan,
    required this.reasoning,
    required this.projectedImpactValue,
    required this.impactType,
    required this.actionSteps,
    this.relatedReference,
    required this.status,
    this.actionedAt,
    required this.generatedAt,
    required this.expiresAt,
  });

  bool get isActioned => status == 'actioned';

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Recommendation(
      id:          json['_id']?.toString() ?? '',
      businessId:  json['business_id']?.toString() ?? '',
      riskId:      json['risk_id']?.toString() ?? '',
      rank:        (json['rank'] as num? ?? 0).toInt(),
      category:    json['category']  as String? ?? '',
      difficulty:  json['difficulty'] as String? ?? '',
      timeframe:   json['timeframe'] as String? ?? '',
      actionTitle: json['action_title'] as String? ?? '',
      actionPlan:  json['action_plan']  as String? ?? '',
      reasoning:   json['reasoning']    as String? ?? '',
      projectedImpactValue:
                   (json['projected_impact_value'] as num? ?? 0).toDouble(),
      impactType:  json['impact_type'] as String? ?? '',
      actionSteps: (json['action_steps'] as List<dynamic>? ?? [])
          .map((s) => ActionStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      relatedReference: json['related_reference'] as String?,
      status:      json['status'] as String? ?? 'active',
      actionedAt:  json['actioned_at'] != null
                     ? _parseDate(json['actioned_at'])
                     : null,
      generatedAt: _parseDate(json['generated_at']),
      expiresAt:   _parseDate(json['expires_at']),
    );
  }

  Recommendation copyWith({String? status, DateTime? actionedAt}) {
    return Recommendation(
      id:                   id,
      businessId:           businessId,
      riskId:               riskId,
      rank:                 rank,
      category:             category,
      difficulty:           difficulty,
      timeframe:            timeframe,
      actionTitle:          actionTitle,
      actionPlan:           actionPlan,
      reasoning:            reasoning,
      projectedImpactValue: projectedImpactValue,
      impactType:           impactType,
      actionSteps:          actionSteps,
      relatedReference:     relatedReference,
      status:               status ?? this.status,
      actionedAt:           actionedAt ?? this.actionedAt,
      generatedAt:          generatedAt,
      expiresAt:            expiresAt,
    );
  }
}

class RecommendationSummary {
  final double totalActionableImpact; // sum excl. Available Financing
  final double cashInflow;
  final double cashBuffer;
  final double costSavings;
  final int    easyActions;
  final int    totalRecommendations;
  final int    canActToday;
  final List<Map<String, dynamic>> impactBreakdown; // [{rank, projected_impact_value, impact_type}]

  const RecommendationSummary({
    required this.totalActionableImpact,
    required this.cashInflow,
    required this.cashBuffer,
    required this.costSavings,
    required this.easyActions,
    required this.totalRecommendations,
    required this.canActToday,
    required this.impactBreakdown,
  });

  factory RecommendationSummary.fromJson(Map<String, dynamic> json) {
    return RecommendationSummary(
      totalActionableImpact: (json['total_actionable_impact'] as num? ?? 0).toDouble(),
      cashInflow:            (json['cash_inflow']            as num? ?? 0).toDouble(),
      cashBuffer:            (json['cash_buffer']            as num? ?? 0).toDouble(),
      costSavings:           (json['cost_savings']           as num? ?? 0).toDouble(),
      easyActions:           (json['easy_actions']           as num? ?? 0).toInt(),
      totalRecommendations:  (json['total_recommendations']  as num? ?? 0).toInt(),
      canActToday:           (json['can_act_today']          as num? ?? 0).toInt(),
      impactBreakdown: (json['impact_breakdown'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}