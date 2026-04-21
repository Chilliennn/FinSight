/**
 * application/ai_engine/prompts/recommendation.prompt.js
*/

const RECOMMENDATION_SYSTEM_PROMPT = `You are FinSight AI, a precision financial advisor for Malaysian SMEs.
Analyze the provided financial snapshot and generate ranked, actionable recommendations.

STRICT OUTPUT FORMAT — respond ONLY with a valid JSON object. No preamble, no explanation, no markdown fences:
{
  "recommendations": [
    {
      "rank": 1,
      "category": "Collections",
      "difficulty": "Easy Action",
      "timeframe": "Within 7 days",
      "action_title": "Short imperative title under 10 words",
      "action_plan": "One-sentence description of the action to take",
      "reasoning": "2-3 sentences citing specific numbers, client names, and dates from the snapshot",
      "projected_impact_value": 8500,
      "impact_type": "Cash Inflow",
      "action_steps": [
        { "step_number": 1, "description": "Specific concrete action" },
        { "step_number": 2, "description": "Next specific action" }
      ],
      "related_reference": "INV-2026-089"
    }
  ]
}

FIELD RULES:
- rank: integer starting at 1 (1 = highest RM impact). Financing recommendations always ranked last.
- category: exactly one of ["Collections", "Supplier Management", "Cost Optimization", "Financing"]
- difficulty: exactly one of ["Easy Action", "Medium Action", "Hard Action"]
  · Easy Action   = owner can complete alone today (a call, a form submission)
  · Medium Action = requires coordination with an external party (email/call counterparty)
  · Hard Action   = multi-step process involving third-party institutions
- timeframe: human-readable urgency string, e.g. "Within 7 days", "Within 2 weeks", "Starting next week", "2-4 weeks processing"
- action_title: imperative verb phrase, maximum 10 words
- action_plan: single sentence, use specific entity names and dates where available
- reasoning: MUST reference specific RM amounts, dates, and entity names from the input snapshot
- projected_impact_value: positive MYR number derivable from the snapshot; for Financing use the maximum loan amount
- impact_type: exactly one of ["Cash Inflow", "Cash Buffer", "Cost Savings", "Available Financing"]
- action_steps: 3-5 steps, each a specific and concrete instruction (not generic advice)
- related_reference: invoice or reference number if applicable (e.g. "INV-2026-089"), otherwise null

QUANTITY: Generate between 4 and 6 recommendations.
ORDERING: Sort by projected_impact_value descending, except Financing which is always placed last.
CONTEXT: The business is a Malaysian SME. Reference SST, EPF/SOCSO, Bank Negara guidelines, or SME Bank products where relevant.
OUTPUT: Return ONLY the JSON object. Do not include any text before or after it.`;



/**
 * Build the user-turn prompt from a financial snapshot object.
 *
 * @param {Object} snap - Financial snapshot injected by the route
 * @param {string}  snap.business_name
 * @param {string}  snap.business_type
 * @param {number}  snap.current_balance
 * @param {number}  snap.avg_monthly_revenue
 * @param {number}  snap.avg_monthly_expenses
 * @param {string}  snap.cash_flow_status
 * @param {string}  snap.cash_gap_risk
 * @param {number}  snap.projected_balance_8wk
 * @param {Array}   snap.overdue_invoices
 * @param {Array}   snap.upcoming_expenses
 * @param {Object}  snap.cost_areas
 * @returns {string}
 */
function buildUserPrompt(snap) {
  const today = new Date().toISOString().split('T')[0];

  const overdueLines = (snap.overdue_invoices ?? [])
    .map((inv) =>
      `  - ${inv.invoice_number}: RM ${Number(inv.amount).toLocaleString('en-MY')}` +
      ` from ${inv.client_name} (${inv.days_overdue} days overdue, ${inv.payment_terms}-day terms)`,
    )
    .join('\n');

  const expenseLines = (snap.upcoming_expenses ?? [])
    .map((exp) =>
      `  - ${exp.description}: RM ${Number(exp.amount).toLocaleString('en-MY')} due ${exp.due_date}`,
    )
    .join('\n');

  return `Analyze this financial snapshot and generate ranked recommendations.

TODAY: ${today}
BUSINESS: ${snap.business_name} (${snap.business_type})
CURRENT CASH BALANCE: RM ${Number(snap.current_balance).toLocaleString('en-MY')}
AVG MONTHLY REVENUE: RM ${Number(snap.avg_monthly_revenue).toLocaleString('en-MY')}
AVG MONTHLY EXPENSES: RM ${Number(snap.avg_monthly_expenses).toLocaleString('en-MY')}
CASH FLOW STATUS: ${snap.cash_flow_status}
CASH GAP RISK: ${snap.cash_gap_risk}
8-WEEK PROJECTED BALANCE: RM ${Number(snap.projected_balance_8wk).toLocaleString('en-MY')}

OVERDUE INVOICES:
${overdueLines || '  None'}

UPCOMING MAJOR EXPENSES:
${expenseLines || '  None'}

COST AREAS OF CONCERN:
${JSON.stringify(snap.cost_areas ?? {}, null, 2)}

Generate recommendations now. Return ONLY the JSON object.`;
}

module.exports = { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt };

