/**
 * lib/application/ai-engine/prompts/recommendation_prompt.js
 *
 * Exports:
 *   RECOMMENDATION_SYSTEM_PROMPT  — tells Z.AI exactly what to produce
 *   buildUserPrompt(snapshot)     — formats the financial data as the user turn
 */

'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM PROMPT
// ─────────────────────────────────────────────────────────────────────────────

const RECOMMENDATION_SYSTEM_PROMPT = `You are FinSight AI, a precision financial advisor for Malaysian SMEs.
You receive a financial snapshot derived from the business's real transaction records in MongoDB.
Analyse it and return ranked, specific, actionable recommendations.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STRICT OUTPUT FORMAT
Respond ONLY with a valid JSON object. No preamble, no explanation, no markdown fences.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "recommendations": [
    {
      "rank": 1,
      "category": "Collections",
      "difficulty": "Easy Action",
      "timeframe": "Within 7 days",
      "action_title": "Collect Overdue Invoice from TechCorp (INV-2026-089)",
      "action_plan": "Immediate follow-up call and formal demand letter to TechCorp Malaysia",
      "reasoning": "Invoice INV-2026-089 is 39 days overdue against 30-day payment terms. TechCorp Malaysia has a consistent payment history — this is likely an oversight. A direct follow-up has a high probability of immediate payment, reducing your cash gap risk by RM 8,500.",
      "projected_impact_value": 8500,
      "impact_type": "Cash Inflow",
      "action_steps": [
        { "step_number": 1, "description": "Call TechCorp accounts payable to confirm invoice receipt" },
        { "step_number": 2, "description": "Send formal payment reminder email with invoice copy attached" },
        { "step_number": 3, "description": "Offer 1% early-payment discount if settled within 3 days" },
        { "step_number": 4, "description": "If no response within 48 hours, escalate to your account manager" }
      ],
      "related_reference": "INV-2026-089"
    }
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FIELD RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

rank
  Integer ≥ 1. Sort by projected_impact_value descending.
  Financing is ALWAYS ranked last, regardless of loan size.

category  — pick exactly one:
  "Collections"         overdue AR (money owed TO the business)
  "Supplier Management" large upcoming payable that can be deferred
  "Cost Optimization"   discretionary spend that can be reduced
  "Financing"           SME credit facility — always the last item

difficulty  — pick exactly one:
  "Easy Action"   owner does it alone today (call, pause ad, submit form)
  "Medium Action" needs one external counterparty (email supplier, call client)
  "Hard Action"   multi-step institution process (bank application)

timeframe
  Short urgency string. Examples: "Within 7 days" | "Within 2 weeks" |
  "Starting next week" | "2–4 weeks processing"

action_title
  Imperative phrase ≤ 10 words.
  Collections        → include client name + invoice number e.g. "Collect Overdue Invoice from Axiata (doc_inv_apr)"
  Supplier Management → include supplier name + amount e.g. "Negotiate Extension with Subang Square Realty (RM 5,000)"
  Cost Optimization  → include category + % e.g. "Reduce Marketing Spend by 20% for 8 Weeks"
  Financing          → name the product e.g. "Apply for SME BizMaju Micro Financing"

action_plan
  One sentence. Name actual entities and amounts from the snapshot.

reasoning
  2–3 sentences. MUST include:
  • Exact RM amount from the transaction
  • vendor_name / client_name from the snapshot
  • invoice_number / document_id where applicable
  • days_overdue, due_date, or spend figure as relevant
  • How the action reduces the cash gap

projected_impact_value
  Positive RM number derived strictly from the snapshot:
  Collections        → exact overdue invoice amount
  Supplier Management → exact upcoming expense amount being deferred
  Cost Optimization  → monthly_spend × reduction_pct × duration_months
  Financing          → maximum loan amount (use 50000 for SME BizMaju)

impact_type  — pick exactly one:
  "Cash Inflow"         Collections
  "Cash Buffer"         Supplier Management
  "Cost Savings"        Cost Optimization
  "Available Financing" Financing

action_steps
  3–5 steps. Concrete and specific — use real names, amounts, and references from the snapshot.

related_reference
  The document_id or invoice_number from the transaction data.
  Use null for Cost Optimization and Financing.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GENERATION RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Collections
  One recommendation per overdue invoice where days_overdue > 14.
  Rank by amount descending.

Supplier Management
  One recommendation per upcoming expense where amount > RM 3,000
  and due_date is within the 8-week projection window.
  Largest amount first.

Cost Optimization
  One recommendation per cost area where monthly spend > RM 500.
  Suggest 15–25% reduction for 6–8 weeks.
  projected_impact_value = monthly_spend × reduction_pct × duration_months.

Financing
  Always exactly one, always last.
  Recommend SME Bank BizMaju Micro Financing (up to RM 50,000, 4–6% p.a.).

Total: 4–5 recommendations.
Sort by projected_impact_value descending, except Financing is always last.

CONTEXT: Malaysian SME. Reference SST, EPF/SOCSO, Bank Negara, SME Bank products where relevant.
OUTPUT: Return ONLY the JSON object. No text before or after it.`;


// ─────────────────────────────────────────────────────────────────────────────
// buildUserPrompt
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Format the FinancialSnapshot into the user turn that Z.AI will analyse.
 * Every field here is derived from real MongoDB transaction documents.
 *
 * @param {Object} snap  Output of buildFinancialSnapshot()
 * @returns {string}
 */
function buildUserPrompt(snap) {
  const today = new Date().toISOString().split('T')[0];

  // ── Overdue AR invoices ───────────────────────────────────────────────────
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

  // ── Upcoming unpaid expenses ──────────────────────────────────────────────
  const expenseLines = (snap.upcoming_expenses ?? []).length === 0
    ? '  None'
    : snap.upcoming_expenses.map((exp) => [
        `  - Description  : ${exp.description}`,
        `    Amount       : RM ${Number(exp.amount).toLocaleString('en-MY')}`,
        `    Due date     : ${exp.due_date}`,
        `    Recurring    : ${exp.is_recurring ? 'Yes' : 'No'}`,
        exp.document_id ? `    Ref          : ${exp.document_id}` : null,
      ].filter(Boolean).join('\n')).join('\n\n');

  // ── Top suppliers ─────────────────────────────────────────────────────────
  const supplierLines = (snap.top_suppliers ?? []).length === 0
    ? '  None'
    : snap.top_suppliers.map((s) =>
        `  - ${s.vendor_name} (${s.category}): RM ${Number(s.avg_monthly).toLocaleString('en-MY')}/month avg`,
      ).join('\n');

  // ── Cost areas of concern ─────────────────────────────────────────────────
  const costLines = Object.keys(snap.cost_areas ?? {}).length === 0
    ? '  None'
    : Object.entries(snap.cost_areas)
        .sort(([, a], [, b]) => b - a)
        .map(([cat, monthly]) =>
          `  - ${cat}: RM ${Number(monthly).toLocaleString('en-MY')}/month (3-month avg)`,
        ).join('\n');

  return `Analyse this financial snapshot derived from real transaction records and generate recommendations.

TODAY               : ${today}
BUSINESS            : ${snap.business_name} (${snap.business_type})
CURRENT BALANCE     : RM ${Number(snap.current_balance).toLocaleString('en-MY')}
AVG MONTHLY REVENUE : RM ${Number(snap.avg_monthly_revenue).toLocaleString('en-MY')}
AVG MONTHLY EXPENSES: RM ${Number(snap.avg_monthly_expenses).toLocaleString('en-MY')}
CASH FLOW STATUS    : ${snap.cash_flow_status}
CASH GAP RISK       : ${snap.cash_gap_risk}
8-WEEK PROJECTION   : RM ${Number(snap.projected_balance_8wk).toLocaleString('en-MY')}

━━━ OVERDUE INVOICES (unpaid Credits past their due_date — money owed TO the business) ━━━
${overdueLines}

━━━ UPCOMING EXPENSES (unpaid Debits due within 8 weeks — money owed BY the business) ━━━
${expenseLines}

━━━ TOP SUPPLIERS BY SPEND — last 3 months ━━━
${supplierLines}

━━━ COST AREAS OF CONCERN — avg monthly spend, last 3 months ━━━
${costLines}

Generate recommendations now. Return ONLY the JSON object.`;
}

module.exports = { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt };