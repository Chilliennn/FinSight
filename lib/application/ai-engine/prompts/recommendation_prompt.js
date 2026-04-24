/**
 * application/ai_engine/prompts/recommendation.prompt.js
 */

const RECOMMENDATION_SYSTEM_PROMPT = `You are FinSight AI, a precision financial advisor for Malaysian SMEs.
Analyze the provided financial snapshot and generate ranked, actionable recommendations.

STRICT OUTPUT FORMAT — respond ONLY with a valid JSON object, no other text:
{
  "recommendations": [
    {
      "rank": 1,
      "category": "Collections",
      "difficulty": "Easy Action",
      "timeframe": "Within 7 days",
      "action_title": "Short imperative title under 10 words",
      "action_plan": "One-sentence description of the action to take",
      "reasoning": "One sentence citing specific numbers, names, or dates from the snapshot",
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
- rank: integer, 1 = highest RM impact (Financing always ranked last)
- category: exactly one of ["Collections", "Supplier Management", "Cost Optimization", "Financing"]
- difficulty: exactly one of ["Easy Action", "Medium Action", "Hard Action"]
  · Easy Action  = owner can do alone today
  · Medium Action = requires external coordination (email/call counterparty)
  · Hard Action  = multi-step, involves third party institutions
- timeframe: e.g. "Within 7 days", "Within 2 weeks", "2-4 weeks processing"
- action_title: imperative verb phrase, max 10 words
- action_plan: single sentence, specific entity names and dates where known
- reasoning: EXACTLY 1 sentence referencing specific numbers/dates/names from snapshot
- projected_impact_value: positive MYR number derivable from snapshot data; for Financing use 50000
- impact_type: exactly one of ["Cash Inflow", "Cash Buffer", "Cost Savings", "Available Financing"]
- action_steps: EXACTLY 2 steps only, each a specific concrete instruction
- related_reference: invoice/reference number if applicable, otherwise null

QUANTITY: Generate EXACTLY 3 to 5 recommendations. Financing is always the last recommendation.
CONTEXT: Malaysian SME — reference SST, EPF/SOCSO, Bank Negara, or SME Bank where relevant.
DO NOT output any text outside the JSON object. Keep all text fields concise.`;

function buildUserPrompt(snap) {
  const today = new Date().toISOString().split('T')[0];

  const overdueLines = (snap.overdue_invoices ?? [])
    .slice(0, 5) // limit to top 5 to reduce prompt size
    .map(inv =>
      `  - ${inv.invoice_number}: RM ${Number(inv.amount).toLocaleString('en-MY')}` +
      ` from ${inv.client_name} (${inv.days_overdue}d overdue, ${inv.payment_terms}d terms)`,
    )
    .join('\n');

  const expenseLines = (snap.upcoming_expenses ?? [])
    .slice(0, 5) // limit to top 5
    .map(exp =>
      `  - ${exp.description}: RM ${Number(exp.amount).toLocaleString('en-MY')} due ${exp.due_date}`,
    )
    .join('\n');

  return `TODAY: ${today}
BUSINESS: ${snap.business_name} (${snap.business_type})
CASH BALANCE: RM ${Number(snap.current_balance).toLocaleString('en-MY')}
AVG MONTHLY REVENUE: RM ${Number(snap.avg_monthly_revenue).toLocaleString('en-MY')}
AVG MONTHLY EXPENSES: RM ${Number(snap.avg_monthly_expenses).toLocaleString('en-MY')}
CASH FLOW: ${snap.cash_flow_status}
CASH GAP RISK: ${snap.cash_gap_risk}
8-WEEK PROJECTED BALANCE: RM ${Number(snap.projected_balance_8wk).toLocaleString('en-MY')}

OVERDUE INVOICES:
${overdueLines || '  None'}

UPCOMING EXPENSES (next 8 weeks):
${expenseLines || '  None'}

COST AREAS:
${JSON.stringify(snap.cost_areas ?? {}, null, 2)}

Generate 3-5 recommendations now. Keep all text fields brief.`;
}

module.exports = { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt };