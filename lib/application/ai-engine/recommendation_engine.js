/**
 * lib/application/ai-engine/recommendation_engine.js
 *
 * Pipeline:
 *   MongoDB transactions
 *     → buildFinancialSnapshot()   aggregate into analysis-ready object
 *     → Z.AI GLM                   generate ranked recommendations as JSON
 *     → validateRecs()             drop malformed entries, warn
 *     → return validated[]         consumed by recommendation_logic.buildRecommendationDocs
 *
 * Transaction schema (lib/data/models/transaction.js):
 *   _id, business_id, document_id, amount, type, category,
 *   txn_date, vendor_name, is_recurring, due_date, is_paid
 *
 *   type === 'Debit'  → money OUT  (rent, payroll, supplies, marketing …)
 *   type === 'Credit' → money IN   (customer payments, AR invoices …)
 */

'use strict';

const { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt } =
  require('./prompts/recommendation_prompt');

// ── Env ───────────────────────────────────────────────────────────────────────
const ZAI_API_KEY  = process.env.ZAI_API_KEY;
const ZAI_BASE_URL = process.env.ZAI_BASE_URL ?? 'https://open.bigmodel.cn/api/paas/v4';

// glm-4-flash was retired — current free-tier model is glm-4.7-flash
const ZAI_MODEL = process.env.ZAI_MODEL ?? 'glm-4.7-flash';

if (!ZAI_API_KEY) {
  throw new Error('[recommendation_engine] ZAI_API_KEY is not set — check your .env file');
}

// ── Valid enum values (must match recommendation.js schema) ───────────────────
const VALID_CATEGORIES   = ['Collections', 'Supplier Management', 'Cost Optimization', 'Financing'];
const VALID_DIFFICULTIES = ['Easy Action', 'Medium Action', 'Hard Action'];
const VALID_IMPACT_TYPES = ['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing'];

// ── Category classification ───────────────────────────────────────────────────
/** Discretionary spend → Cost Optimization recommendations */
const COST_CONCERN_CATEGORIES = new Set([
  'Marketing', 'Advertising', 'Subscriptions', 'Professional Fees', 'Miscellaneous',
]);

/** Fixed/recurring supplier spend → Supplier Management context */
const SUPPLIER_CATEGORIES = new Set([
  'Rent', 'Utilities', 'Insurance', 'Maintenance', 'Supplies', 'Transport', 'Payroll',
]);

// ─────────────────────────────────────────────────────────────────────────────
// buildFinancialSnapshot
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Aggregate raw MongoDB transaction documents into a FinancialSnapshot.
 *
 * @param {Object} opts
 * @param {Array}   opts.transactions   Raw transaction documents from MongoDB
 * @param {string}  opts.businessName
 * @param {string}  opts.businessType
 * @param {number}  opts.currentBalance Current cash balance in RM
 * @returns {Object} FinancialSnapshot passed to buildUserPrompt()
 */
function buildFinancialSnapshot({ transactions, businessName, businessType, currentBalance }) {
  const now      = new Date();
  const eightWks = new Date(now.getTime() + 56 * 24 * 60 * 60 * 1000);

  // 3-month rolling window for averages
  const threeMonthsAgo = new Date(now);
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

  const recent     = transactions.filter((t) => new Date(t.txn_date) >= threeMonthsAgo);
  const paidDebits = recent.filter((t) => t.type === 'Debit'  && t.is_paid === true);
  const paidCredits= recent.filter((t) => t.type === 'Credit' && t.is_paid === true);

  const totalRevenue  = paidCredits.reduce((s, t) => s + Number(t.amount), 0);
  const totalExpenses = paidDebits.reduce((s, t)  => s + Number(t.amount), 0);

  const months = Math.max(
    1,
    (now.getFullYear() * 12 + now.getMonth()) -
    (threeMonthsAgo.getFullYear() * 12 + threeMonthsAgo.getMonth()),
  );

  const avgMonthlyRevenue  = Math.round(totalRevenue  / months);
  const avgMonthlyExpenses = Math.round(totalExpenses / months);

  // ── Overdue AR (unpaid Credits past due_date) → Collections ──────────────
  const overdueInvoices = transactions
    .filter((t) => {
      if (t.type !== 'Credit' || t.is_paid === true) return false;
      const due = new Date(t.due_date ?? t.txn_date);
      return due < now;
    })
    .map((t) => {
      const txnDate = new Date(t.txn_date);
      const dueDate = new Date(t.due_date ?? t.txn_date);
      const daysOverdue  = Math.max(0, Math.floor((now - dueDate) / (1000 * 60 * 60 * 24)));
      const paymentTerms = t.due_date
        ? Math.max(1, Math.round((dueDate - txnDate) / (1000 * 60 * 60 * 24)))
        : 30;
      return {
        invoice_number: t.document_id ?? t._id,
        amount:         Number(t.amount),
        client_name:    t.vendor_name ?? 'Unknown Client',
        days_overdue:   daysOverdue,
        payment_terms:  paymentTerms,
        is_recurring:   t.is_recurring ?? false,
      };
    })
    .sort((a, b) => b.amount - a.amount);

  // ── Upcoming unpaid Debits (due within 8 weeks) → Supplier Management ────
  const upcomingExpenses = transactions
    .filter((t) => {
      if (t.type !== 'Debit' || t.is_paid === true) return false;
      const due = new Date(t.due_date ?? t.txn_date);
      return due >= now && due <= eightWks;
    })
    .map((t) => ({
      description:  t.vendor_name ? `${t.category} — ${t.vendor_name}` : t.category,
      amount:       Number(t.amount),
      due_date:     new Date(t.due_date ?? t.txn_date).toISOString().split('T')[0],
      vendor_name:  t.vendor_name  ?? null,
      category:     t.category     ?? 'Expense',
      is_recurring: t.is_recurring ?? false,
      document_id:  t.document_id  ?? null,
    }))
    .sort((a, b) => new Date(a.due_date) - new Date(b.due_date));

  // ── Discretionary cost areas → Cost Optimization ─────────────────────────
  const costTotals = {};
  for (const txn of paidDebits) {
    if (COST_CONCERN_CATEGORIES.has(txn.category)) {
      costTotals[txn.category] = (costTotals[txn.category] ?? 0) + Number(txn.amount);
    }
  }
  const costAreas = {};
  for (const [cat, total] of Object.entries(costTotals)) {
    costAreas[cat] = Math.round(total / months);
  }

  // ── Top suppliers by spend ────────────────────────────────────────────────
  const supplierTotals = {};
  for (const txn of paidDebits) {
    if (SUPPLIER_CATEGORIES.has(txn.category) && txn.vendor_name) {
      const key = `${txn.category}||${txn.vendor_name}`;
      supplierTotals[key] = (supplierTotals[key] ?? 0) + Number(txn.amount);
    }
  }
  const topSuppliers = Object.entries(supplierTotals)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([key, total]) => {
      const [category, vendor] = key.split('||');
      return { category, vendor_name: vendor, avg_monthly: Math.round(total / months) };
    });

  // ── 8-week cash projection ────────────────────────────────────────────────
  const upcomingDebitTotal  = upcomingExpenses.reduce((s, e) => s + e.amount, 0);
  const projectedRevenue8wk = Math.round((avgMonthlyRevenue / 4.33) * 8);
  const projectedBalance8wk = currentBalance + projectedRevenue8wk - upcomingDebitTotal;

  const netMonthly = avgMonthlyRevenue - avgMonthlyExpenses;
  const cashFlowStatus = netMonthly >= 0
    ? `Positive (RM ${netMonthly.toLocaleString('en-MY')} net/month)`
    : `Negative (RM ${Math.abs(netMonthly).toLocaleString('en-MY')} deficit/month)`;

  const cashGapRisk =
    projectedBalance8wk < 0
      ? `High — projected deficit of RM ${Math.abs(projectedBalance8wk).toLocaleString('en-MY')} within 8 weeks`
      : projectedBalance8wk < avgMonthlyExpenses
      ? `Medium — projected balance RM ${projectedBalance8wk.toLocaleString('en-MY')} is below 1 month of expenses`
      : `Low — RM ${projectedBalance8wk.toLocaleString('en-MY')} projected balance in 8 weeks`;

  return {
    business_name:         businessName,
    business_type:         businessType,
    current_balance:       currentBalance,
    avg_monthly_revenue:   avgMonthlyRevenue,
    avg_monthly_expenses:  avgMonthlyExpenses,
    cash_flow_status:      cashFlowStatus,
    cash_gap_risk:         cashGapRisk,
    projected_balance_8wk: projectedBalance8wk,
    overdue_invoices:      overdueInvoices,
    upcoming_expenses:     upcomingExpenses,
    top_suppliers:         topSuppliers,
    cost_areas:            costAreas,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// generateRecommendations
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Send a FinancialSnapshot to ZhipuAI GLM and return validated recommendation objects.
 *
 * @param {Object} financialSnapshot  Output of buildFinancialSnapshot()
 * @returns {Promise<Array>}
 */
async function generateRecommendations(financialSnapshot) {
  const userPrompt = buildUserPrompt(financialSnapshot);

  let rawText;
  try {
    const response = await fetch(`${ZAI_BASE_URL}/chat/completions`, {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${ZAI_API_KEY}`,
      },
      body: JSON.stringify({
        model:       ZAI_MODEL,
        max_tokens:  4096,
        temperature: 0.1,
        messages: [
          { role: 'system', content: RECOMMENDATION_SYSTEM_PROMPT },
          { role: 'user',   content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`ZhipuAI API ${response.status}: ${errBody.slice(0, 400)}`);
    }

    const data = await response.json();
    rawText = data?.choices?.[0]?.message?.content;
    if (!rawText) {
      throw new Error(`No content in response: ${JSON.stringify(data).slice(0, 300)}`);
    }
  } catch (err) {
    throw new Error(`[recommendation_engine] Z.AI call failed — ${err.message}`);
  }

  // Strip markdown fences
  const cleaned = rawText
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i,     '')
    .replace(/```\s*$/,      '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (err) {
    throw new Error(
      `[recommendation_engine] JSON parse failed — ${err.message}\n` +
      `Raw (first 400): ${rawText.slice(0, 400)}`,
    );
  }

  const recs = parsed?.recommendations;
  if (!Array.isArray(recs) || recs.length === 0) {
    throw new Error('[recommendation_engine] No recommendations array in Z.AI response');
  }

  const validated = recs.filter((rec, idx) => {
    const issues = [];
    if (!VALID_CATEGORIES.includes(rec.category))       issues.push(`invalid category "${rec.category}"`);
    if (!VALID_DIFFICULTIES.includes(rec.difficulty))   issues.push(`invalid difficulty "${rec.difficulty}"`);
    if (!VALID_IMPACT_TYPES.includes(rec.impact_type))  issues.push(`invalid impact_type "${rec.impact_type}"`);
    if (typeof rec.projected_impact_value !== 'number' || rec.projected_impact_value <= 0)
                                                         issues.push('invalid projected_impact_value');
    if (!rec.action_title?.trim())                       issues.push('missing action_title');
    if (!rec.action_plan?.trim())                        issues.push('missing action_plan');
    if (!rec.reasoning?.trim())                          issues.push('missing reasoning');
    if (!Array.isArray(rec.action_steps) || rec.action_steps.length === 0)
                                                         issues.push('missing action_steps');
    if (issues.length > 0) {
      console.warn(`[recommendation_engine] Dropping rec #${idx + 1}: ${issues.join(', ')}`);
      return false;
    }
    return true;
  });

  if (validated.length === 0) {
    throw new Error('[recommendation_engine] All recommendations failed validation');
  }

  return validated;
}

module.exports = { generateRecommendations, buildFinancialSnapshot };