// lib/application/ai-engine/recommendation_engine.js

'use strict';

const { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt } =
  require('./prompts/recommendation_prompt');
const { client } = require('./openaiClient');

// ── Env ───────────────────────────────────────────────────────────────────────
const ZAI_BASE_URL = (process.env.ZAI_BASE_URL ?? '').replace(/\/$/, '');
const ZAI_MODEL    = process.env.ZAI_MODEL;
const MAX_TOKENS   = Number(process.env.AI_MAX_TOKENS ?? 8000);

if (!ZAI_BASE_URL) throw new Error('[recommendation_engine] ZAI_BASE_URL is not set');
if (!ZAI_MODEL)    throw new Error('[recommendation_engine] ZAI_MODEL is not set');

console.log(`[recommendation_engine] model: ${ZAI_MODEL} | base: ${ZAI_BASE_URL}`);

// ── Valid enum values (must match recommendation.js schema) ───────────────────
const VALID_CATEGORIES   = ['Collections', 'Supplier Management', 'Cost Optimization', 'Financing'];
const VALID_DIFFICULTIES = ['Easy Action', 'Medium Action', 'Hard Action'];
const VALID_IMPACT_TYPES = ['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing'];

// ── Category classification ───────────────────────────────────────────────────
const COST_CONCERN_CATEGORIES = new Set([
  'Marketing', 'Advertising', 'Subscriptions', 'Professional Fees', 'Miscellaneous', 'COGS', 'Salaries', 'Utilities',
]);

const SUPPLIER_CATEGORIES = new Set([
  'Rent', 'Utilities', 'Insurance', 'Maintenance', 'Supplies', 'Transport', 'Payroll',
]);

// ─────────────────────────────────────────────────────────────────────────────
// buildFinancialSnapshot
// ─────────────────────────────────────────────────────────────────────────────

function buildFinancialSnapshot({ transactions, businessName, businessType, currentBalance }) {
  const now      = new Date();
  const eightWks = new Date(now.getTime() + 56 * 24 * 60 * 60 * 1000);

  const threeMonthsAgo = new Date(now);
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

  const recent      = transactions.filter((t) => new Date(t.txn_date) >= threeMonthsAgo);
  const paidDebits  = recent.filter((t) => t.type === 'Debit'  && t.is_paid === true);
  const paidCredits = recent.filter((t) => t.type === 'Credit' && t.is_paid === true);

  const totalRevenue  = paidCredits.reduce((s, t) => s + Number(t.amount), 0);
  const totalExpenses = paidDebits.reduce((s, t)  => s + Number(t.amount), 0);

  const months = Math.max(
    1,
    (now.getFullYear() * 12 + now.getMonth()) -
    (threeMonthsAgo.getFullYear() * 12 + threeMonthsAgo.getMonth()),
  );

  const avgMonthlyRevenue  = Math.round(totalRevenue  / months);
  const avgMonthlyExpenses = Math.round(totalExpenses / months);

  const overdueInvoices = transactions
    .filter((t) => {
      if (t.type !== 'Credit' || t.is_paid === true) return false;
      const due = new Date(t.due_date ?? t.txn_date);
      return due < now;
    })
    .map((t) => {
      const txnDate     = new Date(t.txn_date);
      const dueDate     = new Date(t.due_date ?? t.txn_date);
      const daysOverdue = Math.max(0, Math.floor((now - dueDate) / (1000 * 60 * 60 * 24)));
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

  const supplierTotals = {};
  for (const txn of paidDebits) {
    if (SUPPLIER_CATEGORIES.has(txn.category) && txn.vendor_name) {
      const key = `${txn.category}||${txn.vendor_name}`;
      supplierTotals[key] = (supplierTotals[key] ?? 0) + Number(txn.amount);
    }
  }
  const topSuppliers = Object.entries(supplierTotals)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 4)
    .map(([key, total]) => {
      const [category, vendor] = key.split('||');
      return { category, vendor_name: vendor, avg_monthly: Math.round(total / months) };
    });

  const upcomingDebitTotal  = upcomingExpenses.reduce((s, e) => s + e.amount, 0);
  const projectedRevenue8wk = Math.round((avgMonthlyRevenue / 4.33) * 8);
  const projectedBalance8wk = currentBalance + projectedRevenue8wk - upcomingDebitTotal;

  const netMonthly     = avgMonthlyRevenue - avgMonthlyExpenses;
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
// callAI  — single AI call, returns parsed recommendations array
// ─────────────────────────────────────────────────────────────────────────────

async function callAI(prompt, label, retries = 2) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    console.log(`[recommendation_engine] ${label} attempt ${attempt}/${retries}...`);
    try {
      const response = await client.chat.completions.create({
        model:      ZAI_MODEL,
        max_tokens: MAX_TOKENS,
        messages:   [{ role: 'user', content: prompt }],
      });

      const finishReason = response.choices[0]?.finish_reason;
      const rawText      = response.choices[0]?.message?.content;

      console.log(`[recommendation_engine] ${label} finish_reason: ${finishReason} | tokens: ${response.usage?.completion_tokens}`);

      if (!rawText) {
        console.warn(`[recommendation_engine] ${label} returned null content — skipping`);
        return [];
      }

      const cleaned = rawText
        .replace(/^```json\s*/i, '')
        .replace(/^```\s*/i,     '')
        .replace(/```\s*$/,      '')
        .trim();

      try {
        const parsed = JSON.parse(cleaned);
        return parsed?.recommendations ?? [];
      } catch (err) {
        console.warn(`[recommendation_engine] ${label} JSON parse failed — skipping: ${err.message}`);
        return [];
      }
    } catch (err) {
      const is504 = err.message?.includes('504') || err.status === 504;
      console.warn(`[recommendation_engine] ${label} attempt ${attempt} failed: ${err.message}`);
      if (attempt < retries && is504) {
        const delay = attempt * 5000;
        console.log(`[recommendation_engine] Retrying ${label} in ${delay}ms...`);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      throw err;
    }
  }
  return [];
}

// ─────────────────────────────────────────────────────────────────────────────
// validateRec  — returns array of issue strings (empty = valid)
// ─────────────────────────────────────────────────────────────────────────────

function validateRec(rec) {
  const issues = [];
  if (!VALID_CATEGORIES.includes(rec.category))      issues.push(`invalid category "${rec.category}"`);
  if (!VALID_DIFFICULTIES.includes(rec.difficulty))  issues.push(`invalid difficulty "${rec.difficulty}"`);
  if (!VALID_IMPACT_TYPES.includes(rec.impact_type)) issues.push(`invalid impact_type "${rec.impact_type}"`);
  if (typeof rec.projected_impact_value !== 'number' || rec.projected_impact_value <= 0)
                                                      issues.push('invalid projected_impact_value');
  if (!rec.action_title?.trim())                      issues.push('missing action_title');
  if (!rec.action_plan?.trim())                       issues.push('missing action_plan');
  if (!rec.reasoning?.trim())                         issues.push('missing reasoning');
  if (!Array.isArray(rec.action_steps) || rec.action_steps.length === 0)
                                                      issues.push('missing action_steps');
  return issues;
}

// ─────────────────────────────────────────────────────────────────────────────
// generateRecommendations
// ─────────────────────────────────────────────────────────────────────────────

async function generateRecommendations(financialSnapshot) {
  const userPrompt = buildUserPrompt(financialSnapshot);

  console.log(`[recommendation_engine] Starting sequential AI calls | model: ${ZAI_MODEL}`);

  const call1Prompt = [
    RECOMMENDATION_SYSTEM_PROMPT,
    '',
    'INSTRUCTION: Generate ONLY "Collections" and "Supplier Management" recommendations.',
    'Generate 2-3 recommendations total. Skip a category if no qualifying data exists.',
    'Keep reasoning to 1 sentence. Exactly 2 action_steps. Be concise.',
    '',
    userPrompt,
  ].join('\n');

  const call2Prompt = [
    RECOMMENDATION_SYSTEM_PROMPT,
    '',
    'INSTRUCTION: Generate ONLY "Cost Optimization" and "Financing" recommendations.',
    'Always include exactly one Financing rec. Include Cost Optimization only if cost areas exist.',
    'Generate 2-3 recommendations total.',
    'Keep reasoning to 1 sentence. Exactly 2 action_steps. Be concise.',
    '',
    userPrompt,
  ].join('\n');

  // ── Sequential — avoids 504 from concurrent load ──────────────────────────
  let recs1 = [];
  let recs2 = [];

  try {
    recs1 = await callAI(call1Prompt, 'Call 1 (Collections + Supplier)');
  } catch (err) {
    console.warn('[recommendation_engine] Call 1 failed after retries:', err.message);
  }

  try {
    recs2 = await callAI(call2Prompt, 'Call 2 (Cost + Financing)');
  } catch (err) {
    console.warn('[recommendation_engine] Call 2 failed after retries:', err.message);
  }

  const allRecs = [...recs1, ...recs2];

  if (allRecs.length === 0) {
    throw new Error('[recommendation_engine] Both AI calls returned no recommendations');
  }

  const validated = allRecs.filter((rec, idx) => {
    const issues = validateRec(rec);
    if (issues.length > 0) {
      console.warn(`[recommendation_engine] Dropping rec #${idx + 1}: ${issues.join(', ')}`);
      return false;
    }
    return true;
  });

  if (validated.length === 0) {
    throw new Error('[recommendation_engine] All recommendations failed validation');
  }

  const financing    = validated.filter((r) => r.category === 'Financing');
  const nonFinancing = validated
    .filter((r) => r.category !== 'Financing')
    .sort((a, b) => b.projected_impact_value - a.projected_impact_value);

  const reranked = [...nonFinancing, ...financing].map((r, i) => ({ ...r, rank: i + 1 }));

  console.log(`[recommendation_engine] Generated ${reranked.length} recommendations`);
  return reranked;
}

module.exports = { generateRecommendations, buildFinancialSnapshot };