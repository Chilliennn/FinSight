// lib/data/models/recommendation_model.dart

class ActionStep {
  final int    stepNumber;
  final String description;

  const ActionStep({
    required this.stepNumber,
    required this.description,
  });

  factory ActionStep.fromJson(Map<String, dynamic> json) => ActionStep(
        stepNumber:  (json['step_number']  as num).toInt(),
        description:  json['description']  as String,
      );

  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'description': description,
      };
}

// ── Main recommendation model ─────────────────────────────────────────────────

class Recommendation {
  final String   id;
  final String   businessId;
  final String   riskId;
  final int      rank;
  final String   category;
  final String   difficulty;
  final String   timeframe;
  final String   actionTitle;          // DB: action_title
  final String   actionPlan;           // DB: action_plan
  final String   reasoning;            // DB: reasoning
  final double   projectedImpactValue; // DB: projected_impact_value
  final String   impactType;           // DB: impact_type
  final List<ActionStep> actionSteps;  // DB: action_steps
  final String?  relatedReference;     // DB: related_reference
  final String   status;               // 'active' | 'actioned' | 'dismissed' | 'expired'
  final DateTime? actionedAt;          // DB: actioned_at
  final DateTime generatedAt;          // DB: generated_at
  final DateTime expiresAt;            // DB: expires_at

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
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Recommendation(
      id:                   json['_id']?.toString()         ?? '',
      businessId:           json['business_id']?.toString() ?? '',
      riskId:               json['risk_id']?.toString()     ?? '',
      rank:                 (json['rank']                   as num? ?? 0).toInt(),
      category:             json['category']                as String? ?? '',
      difficulty:           json['difficulty']              as String? ?? '',
      timeframe:            json['timeframe']               as String? ?? '',
      actionTitle:          json['action_title']            as String? ?? '',
      actionPlan:           json['action_plan']             as String? ?? '',
      reasoning:            json['reasoning']               as String? ?? '',
      projectedImpactValue: (json['projected_impact_value'] as num? ?? 0).toDouble(),
      impactType:           json['impact_type']             as String? ?? '',
      actionSteps: (json['action_steps'] as List<dynamic>? ?? [])
          .map((s) => ActionStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      relatedReference: json['related_reference']           as String?,
      status:           json['status']                      as String? ?? 'active',
      actionedAt:       json['actioned_at'] != null ? parseDate(json['actioned_at']) : null,
      generatedAt:      parseDate(json['generated_at']),
      expiresAt:        parseDate(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id':                    id,
        'business_id':            businessId,
        'risk_id':                riskId,
        'rank':                   rank,
        'category':               category,
        'difficulty':             difficulty,
        'timeframe':              timeframe,
        'action_title':           actionTitle,
        'action_plan':            actionPlan,
        'reasoning':              reasoning,
        'projected_impact_value': projectedImpactValue,
        'impact_type':            impactType,
        'action_steps':           actionSteps.map((s) => s.toJson()).toList(),
        'related_reference':      relatedReference,
        'status':                 status,
        'actioned_at':            actionedAt?.toIso8601String(),
        'generated_at':           generatedAt.toIso8601String(),
        'expires_at':             expiresAt.toIso8601String(),
      };

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
      status:               status              ?? this.status,
      actionedAt:           actionedAt          ?? this.actionedAt,
      generatedAt:          generatedAt,
      expiresAt:            expiresAt,
    );
  }
}


class RecommendationSummary {
  final double totalActionableImpact; // sum excl. 'Available Financing'
  final double cashInflow;
  final double cashBuffer;
  final double costSavings;
  final int    easyActions;
  final int    totalRecommendations;
  final int    canActToday;
  final List<Map<String, dynamic>> impactBreakdown;

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