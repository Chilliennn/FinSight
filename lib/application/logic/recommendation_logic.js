/**
 * application/logic/recommendation.logic.js
 *
 * Pure deterministic business logic — no I/O, no DB, no AI calls.
 * All functions receive data as arguments (injected by routes/) and return results.
 *
 * ARCHITECTURE RULES:
 *   - ZERO imports (not even from node_modules except built-ins if needed)
 *   - Called BY application/routes/recommendation.routes.js ONLY
 *   - Results are passed back to routes/ — never stored here
 */

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Transform validated raw Z.AI recommendation objects into MongoDB-ready documents.
 *
 * Field mapping (raw Z.AI output → DB document):
 *   rank, category, difficulty, timeframe   → unchanged
 *   action_title                            → action_title
 *   action_plan                             → action_plan
 *   reasoning                               → reasoning
 *   projected_impact_value                  → projected_impact_value (rounded int)
 *   impact_type                             → impact_type
 *   action_steps [{step_number, description}] → action_steps
 *   related_reference                       → related_reference (string | null)
 *
 * @param {Array}  rawRecs    - Validated raw objects from ai_engine (injected by routes/)
 * @param {string} businessId
 * @param {string} riskId     - The risk_id that triggered this generation
 * @returns {Array<Object>}   DB-ready documents (_id omitted — repository assigns it)
 */
function buildRecommendationDocs(rawRecs, businessId, riskId) {
  const now       = new Date();
  const expiresAt = new Date(now.getTime() + SEVEN_DAYS_MS);

  return rawRecs.map((rec, idx) => ({
    // _id intentionally omitted — repository assigns ObjectId on insert
    business_id: businessId,
    risk_id:     riskId,

    rank:       Number.isInteger(rec.rank) && rec.rank > 0 ? rec.rank : idx + 1,
    category:   rec.category,
    difficulty: rec.difficulty,
    timeframe:  (rec.timeframe ?? 'This week').trim(),

    action_title: rec.action_title.trim(),
    action_plan:  rec.action_plan.trim(),
    reasoning:    rec.reasoning.trim(),

    projected_impact_value: Math.round(rec.projected_impact_value),
    impact_type:            rec.impact_type,

    action_steps: (rec.action_steps ?? []).map((step, i) => ({
      step_number: Number.isInteger(step.step_number) ? step.step_number : i + 1,
      description: step.description.trim(),
    })),

    related_reference: rec.related_reference ?? null,

    status:       'active',
    actioned_at:  null,
    generated_at: now,
    expires_at:   expiresAt,
  }));
}

/**
 * Calculate the aggregated financial impact summary from a list of
 * recommendation documents (as returned by the repository).
 *
 * Rules:
 *   - "Available Financing" is excluded from total_actionable_impact
 *   - impact_breakdown preserves rank order for the Flutter bar chart
 *
 * @param {Array<Object>} recommendations - Documents from repository
 * @returns {Object} Summary object consumed by the Flutter ImpactSummaryCard widget
 */
function calculateImpactSummary(recommendations) {
  const nonFinancing = recommendations.filter(
    r => r.impact_type !== 'Available Financing',
  );

  const sumField = (arr, field) =>
    arr.reduce((acc, r) => acc + (r[field] ?? 0), 0);

  const cashInflow  = sumField(
    recommendations.filter(r => r.impact_type === 'Cash Inflow'),
    'projected_impact_value',
  );
  const cashBuffer  = sumField(
    recommendations.filter(r => r.impact_type === 'Cash Buffer'),
    'projected_impact_value',
  );
  const costSavings = sumField(
    recommendations.filter(r => r.impact_type === 'Cost Savings'),
    'projected_impact_value',
  );
  const totalImpact = sumField(nonFinancing, 'projected_impact_value');

  const easyActions = recommendations.filter(
    r => r.difficulty === 'Easy Action',
  ).length;

  const canActToday = recommendations.filter(r => {
    const tf = (r.timeframe ?? '').toLowerCase();
    return (
      tf.includes('today') ||
      tf.includes('7 days') ||
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
    impact_breakdown: recommendations.map(r => ({
      rank:                   r.rank,
      projected_impact_value: r.projected_impact_value,
      impact_type:            r.impact_type,
    })),
  };
}

module.exports = {
  buildRecommendationDocs,
  calculateImpactSummary,
};