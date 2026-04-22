// lib/presentation/actions/recommendation_model.dart


class ActionStep {
  final int    stepNumber;
  final String description;

  const ActionStep({required this.stepNumber, required this.description});

  factory ActionStep.fromJson(Map<String, dynamic> j) => ActionStep(
        stepNumber:  (j['step_number'] as num).toInt(),
        description:  j['description'] as String,
      );
}

class Recommendation {
  final String   id;
  final String   businessId;
  final String   riskId;
  final int      rank;
  final String   category;
  final String   difficulty;
  final String   timeframe;
  final String   actionTitle;
  final String   actionPlan;
  final String   reasoning;
  final double   projectedImpactValue;
  final String   impactType;
  final List<ActionStep> actionSteps;
  final String?  relatedReference;
  final String   status;
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

  factory Recommendation.fromJson(Map<String, dynamic> j) {
    DateTime d(dynamic v) =>
        v is String ? DateTime.tryParse(v) ?? DateTime.now() : DateTime.now();

    return Recommendation(
      id:                   j['_id']?.toString()         ?? '',
      businessId:           j['business_id']?.toString() ?? '',
      riskId:               j['risk_id']?.toString()     ?? '',
      rank:                 (j['rank']                   as num? ?? 0).toInt(),
      category:             j['category']                as String? ?? '',
      difficulty:           j['difficulty']              as String? ?? '',
      timeframe:            j['timeframe']               as String? ?? '',
      actionTitle:          j['action_title']            as String? ?? '',
      actionPlan:           j['action_plan']             as String? ?? '',
      reasoning:            j['reasoning']               as String? ?? '',
      projectedImpactValue: (j['projected_impact_value'] as num? ?? 0).toDouble(),
      impactType:           j['impact_type']             as String? ?? '',
      actionSteps: (j['action_steps'] as List<dynamic>? ?? [])
          .map((s) => ActionStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      relatedReference: j['related_reference'] as String?,
      status:           j['status']            as String? ?? 'active',
      actionedAt:       j['actioned_at'] != null ? d(j['actioned_at']) : null,
      generatedAt:      d(j['generated_at']),
      expiresAt:        d(j['expires_at']),
    );
  }
}

class RecommendationSummary {
  final double totalActionableImpact;
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

  factory RecommendationSummary.fromJson(Map<String, dynamic> j) =>
      RecommendationSummary(
        totalActionableImpact: (j['total_actionable_impact'] as num? ?? 0).toDouble(),
        cashInflow:            (j['cash_inflow']            as num? ?? 0).toDouble(),
        cashBuffer:            (j['cash_buffer']            as num? ?? 0).toDouble(),
        costSavings:           (j['cost_savings']           as num? ?? 0).toDouble(),
        easyActions:           (j['easy_actions']           as num? ?? 0).toInt(),
        totalRecommendations:  (j['total_recommendations']  as num? ?? 0).toInt(),
        canActToday:           (j['can_act_today']          as num? ?? 0).toInt(),
        impactBreakdown: (j['impact_breakdown'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}