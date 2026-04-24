/**
 * lib/application/ai-engine/prompts/recommendation_prompt.js
 */

'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM PROMPT  (concise — keeps all rules, removes decorators & examples)
// ─────────────────────────────────────────────────────────────────────────────

const RECOMMENDATION_SYSTEM_PROMPT = `You are FinSight AI, a financial advisor for Malaysian SMEs.
Analyse the financial snapshot and return ONLY a valid JSON object — no preamble, no markdown fences.

OUTPUT FORMAT:
{"recommendations":[{
  "rank": 1,
  "category": "Collections|Supplier Management|Cost Optimization|Financing",
  "difficulty": "Easy Action|Medium Action|Hard Action",
  "timeframe": "Within 7 days",
  "action_title": "Imperative phrase ≤10 words with entity name and amount",
  "action_plan": "One sentence naming real entities and amounts from snapshot",
  "reasoning": "2-3 sentences with exact RM amount, vendor/client name, doc ref, days overdue, and how it reduces cash gap",
  "projected_impact_value": 1000,
  "impact_type": "Cash Inflow|Cash Buffer|Cost Savings|Available Financing",
  "action_steps": [{"step_number": 1, "description": "Concrete step with real names and amounts"}],
  "related_reference": "document_id or null"
}]}

CATEGORY RULES:
- Collections: maximum 2 recs for the highest-value overdue invoices where days_overdue > 14, ranked by amount desc. impact_type=Cash Inflow, related_reference=invoice ref, projected_impact_value=invoice amount
- Supplier Management: maximum 1 rec for the single highest upcoming expense > RM3000 due within 8 weeks. impact_type=Cash Buffer, projected_impact_value=expense amount
- Cost Optimization: one rec per cost area with monthly spend > RM500. Suggest 15-25% reduction for 6-8 weeks. impact_type=Cost Savings, projected_impact_value=monthly_spend×reduction_pct×duration_months, related_reference=null
- Financing: exactly one, always last. Recommend SME Bank BizMaju Micro Financing up to RM50000 at 4-6% pa. impact_type=Available Financing, projected_impact_value=50000, related_reference=null

FIELD RULES:
- difficulty: Easy Action=owner acts alone today | Medium Action=needs one external party | Hard Action=multi-step institution process
- action_steps: 3-5 steps, concrete, use real names/amounts/refs from snapshot
- Total: 4-5 recommendations, sorted by projected_impact_value desc except Financing always last
- Context: Malaysian SME — reference SST, EPF/SOCSO, Bank Negara, SME Bank where relevant`;


// ─────────────────────────────────────────────────────────────────────────────
// buildUserPrompt
// ─────────────────────────────────────────────────────────────────────────────

function buildUserPrompt(snap) {
  const today = new Date().toISOString().split('T')[0];

  const overdueLines = (snap.overdue_invoices ?? []).length === 0
    ? '  None'
    : snap.overdue_invoices.map((inv) => [
        `  - Invoice ref  : ${inv.invoice_number}`,
        `    Client       : ${inv.client_name}`,
        `    Amount       : RM ${Number(inv.amount).toLocaleString('en-MY')}`,
        `    Days overdue : ${inv.days_overdue}`,
        `    Payment terms: ${inv.payment_terms} days`,
        `    Recurring    : ${inv.is_recurring ? 'Yes' : 'No'}`,
      ].join('\n')).join('\n\n');

  const expenseLines = (snap.upcoming_expenses ?? []).length === 0
    ? '  None'
    : snap.upcoming_expenses.map((exp) => [
        `  - Description  : ${exp.description}`,
        `    Amount       : RM ${Number(exp.amount).toLocaleString('en-MY')}`,
        `    Due date     : ${exp.due_date}`,
        `    Recurring    : ${exp.is_recurring ? 'Yes' : 'No'}`,
        exp.document_id ? `    Ref          : ${exp.document_id}` : null,
      ].filter(Boolean).join('\n')).join('\n\n');

  const supplierLines = (snap.top_suppliers ?? []).length === 0
    ? '  None'
    : snap.top_suppliers.map((s) =>
        `  - ${s.vendor_name} (${s.category}): RM ${Number(s.avg_monthly).toLocaleString('en-MY')}/month avg`,
      ).join('\n');

  const costLines = Object.keys(snap.cost_areas ?? {}).length === 0
    ? '  None'
    : Object.entries(snap.cost_areas)
        .sort(([, a], [, b]) => b - a)
        .map(([cat, monthly]) =>
          `  - ${cat}: RM ${Number(monthly).toLocaleString('en-MY')}/month (3-month avg)`,
        ).join('\n');

  return `Analyse this financial snapshot and generate recommendations.

TODAY               : ${today}
BUSINESS            : ${snap.business_name} (${snap.business_type})
CURRENT BALANCE     : RM ${Number(snap.current_balance).toLocaleString('en-MY')}
AVG MONTHLY REVENUE : RM ${Number(snap.avg_monthly_revenue).toLocaleString('en-MY')}
AVG MONTHLY EXPENSES: RM ${Number(snap.avg_monthly_expenses).toLocaleString('en-MY')}
CASH FLOW STATUS    : ${snap.cash_flow_status}
CASH GAP RISK       : ${snap.cash_gap_risk}
8-WEEK PROJECTION   : RM ${Number(snap.projected_balance_8wk).toLocaleString('en-MY')}

OVERDUE INVOICES (money owed TO the business):
${overdueLines}

UPCOMING EXPENSES (due within 8 weeks):
${expenseLines}

TOP SUPPLIERS (last 3 months):
${supplierLines}

COST AREAS OF CONCERN (avg monthly, last 3 months):
${costLines}

Return ONLY the JSON object.`;
}

module.exports = { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt };