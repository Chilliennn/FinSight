/**
 * lib/application/logic/recommendation_logic.js
 *
 * Two responsibilities:
 *
 *  1. buildRecommendationDocs(rawRecs, businessId, riskId)
 *     Maps validated Z.AI output → MongoDB documents that satisfy the
 *     recommendation.js JSON Schema exactly. Every required field is set here.
 *     _id is intentionally omitted — recommendationRepository.replaceAll() assigns it.
 *
 *  2. calculateImpactSummary(recommendations)
 *     Aggregates stored recommendation documents into the summary object
 *     consumed by the Flutter ImpactSummaryCard widget.
 *
 * ── Field origin map ─────────────────────────────────────────────────────────
 *
 *  DB field                 Source
 *  ─────────────────────    ──────────────────────────────────────────────────
 *  _id                      recommendationRepository (ObjectId hex string)
 *  business_id              caller (route parameter)
 *  risk_id                  caller (route body)
 *  rank                     Z.AI → coerced to Int32 by repository
 *  category                 Z.AI → validated in engine
 *  difficulty               Z.AI → validated in engine
 *  timeframe                Z.AI (default "This week" if blank)
 *  action_title             Z.AI
 *  action_plan              Z.AI
 *  reasoning                Z.AI
 *  projected_impact_value   Z.AI → Math.round → stored as double/int
 *  impact_type              Z.AI → validated in engine
 *  action_steps[]           Z.AI → step_number coerced to Int32 by repository
 *  related_reference        Z.AI (string | null)
 *  status                   hardcoded "active"
 *  actioned_at              hardcoded null
 *  generated_at             new Date() at generation time
 *  expires_at               generated_at + 90 days
 */

'use strict';

const { Int32 } = require('mongodb');

// Recommendations expire after 90 days (adjust as needed)
const EXPIRES_AFTER_MS = 90 * 24 * 60 * 60 * 1000;

// ─────────────────────────────────────────────────────────────────────────────
// buildRecommendationDocs
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Transform validated raw Z.AI recommendation objects into MongoDB-ready documents.
 *
 * @param {Array}  rawRecs    Validated objects from recommendation_engine.generateRecommendations()
 * @param {string} businessId FK → businesses._id
 * @param {string} riskId     FK → riskAlerts._id that triggered generation
 * @returns {Array<Object>}   DB-ready documents without _id (assigned by repository)
 */
function buildRecommendationDocs(rawRecs, businessId, riskId) {
  const generatedAt = new Date();
  const expiresAt   = new Date(generatedAt.getTime() + EXPIRES_AFTER_MS);

  return rawRecs.map((rec, idx) => {
    // Rank: use Z.AI value if valid, otherwise fall back to array position
    const rank = Number.isInteger(rec.rank) && rec.rank >= 1 ? rec.rank : idx + 1;

    return {
      // _id omitted — repository assigns ObjectId hex string on insert

      // ── Identity fields ─────────────────────────────────────────────────
      business_id: businessId,
      risk_id:     riskId,

      // ── Z.AI generated fields ───────────────────────────────────────────
      // rank and step_number are stored as Int32 (coerced by repository.coerceIntFields)
      rank:       new Int32(rank),
      category:   rec.category,
      difficulty: rec.difficulty,
      timeframe:  (rec.timeframe ?? 'This week').trim(),

      action_title: rec.action_title.trim(),
      action_plan:  rec.action_plan.trim(),
      reasoning:    rec.reasoning.trim(),

      // projected_impact_value: schema allows double or int — Math.round returns JS number
      projected_impact_value: Math.round(rec.projected_impact_value),
      impact_type:            rec.impact_type,

      // action_steps: step_number coerced to Int32 by repository.coerceIntFields
      action_steps: (rec.action_steps ?? []).map((step, i) => ({
        step_number: new Int32(
          Number.isInteger(step.step_number) && step.step_number >= 1
            ? step.step_number
            : i + 1,
        ),
        description: step.description.trim(),
      })),

      // related_reference: invoice/document ref from Z.AI, or null
      related_reference: rec.related_reference ?? null,

      // ── Status fields ────────────────────────────────────────────────────
      status:      'active',
      actioned_at: null,

      // ── Timestamps ───────────────────────────────────────────────────────
      generated_at: generatedAt,
      expires_at:   expiresAt,
    };
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// calculateImpactSummary
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Aggregate financial impact from stored recommendation documents.
 * "Available Financing" is excluded from the total actionable figure
 * because it is a credit facility, not guaranteed cash.
 *
 * @param {Array<Object>} recommendations  Documents from repository
 * @returns {Object}  Summary consumed by Flutter ImpactSummaryCard widget
 */
function calculateImpactSummary(recommendations) {
  const sum = (arr) => arr.reduce((acc, r) => acc + (Number(r.projected_impact_value) || 0), 0);

  const byType = (type) => recommendations.filter((r) => r.impact_type === type);

  const cashInflow  = sum(byType('Cash Inflow'));
  const cashBuffer  = sum(byType('Cash Buffer'));
  const costSavings = sum(byType('Cost Savings'));

  // Total excludes Available Financing
  const nonFinancing  = recommendations.filter((r) => r.impact_type !== 'Available Financing');
  const totalImpact   = sum(nonFinancing);

  const easyActions = recommendations.filter((r) => r.difficulty === 'Easy Action').length;

  // "Can act today" = timeframe mentions today, within 7 days, or within 1 week
  const canActToday = recommendations.filter((r) => {
    const tf = (r.timeframe ?? '').toLowerCase();
    return (
      tf.includes('today') ||
      tf.includes('7 day') ||
      (tf.includes('week') && !tf.includes('2 week') && !tf.includes('2-'))
    );
  }).length;

  return {
    total_actionable_impact: totalImpact,
    cash_inflow:             cashInflow,
    cash_buffer:             cashBuffer,
    cost_savings:            costSavings,
    easy_actions:            easyActions,
    total_recommendations:   recommendations.length,
    can_act_today:           canActToday,
    impact_breakdown: recommendations.map((r) => ({
      rank:                   Number(r.rank),
      projected_impact_value: Number(r.projected_impact_value),
      impact_type:            r.impact_type,
    })),
  };
}

module.exports = { buildRecommendationDocs, calculateImpactSummary };