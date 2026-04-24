/**
 * Risk Detector — Deterministic rules only.
 *
 * Per Manifesto §3: no AI code here.
 * Per Manifesto §5: no DB driver imports — all data comes via repositories.
 */

const transactionRepo = require('../../data/repositories/transactionRepository');

const config = {
  cashFlowGap: {
    forecastWeeks: 8,
    lookbackWeeks: 8,
    severity: 'critical'
  },
  overdueInvoices: {
    highCountThreshold: 3,
    highAmountThreshold: 15000
  },
  expenseSpike: {
    minIncreasePct: 0.20,
    highSeverityPct: 0.30
  },
  revenueDecline: {
    minConsecutiveMonths: 3,
    severity: 'medium'
  },
  largePayable: {
    balanceRatio: 0.20,
    severity: 'medium'
  }
};

async function detectAll(businessId, opts = {}) {
  const today = opts.today ? new Date(opts.today) : new Date();

  console.log('[riskDetector] detectAll called for:', businessId);
  const allTxns = await transactionRepo.list({ business_id: businessId });
  console.log('[riskDetector] total transactions found:', allTxns.length);
  if (allTxns.length > 0) {
    console.log('[riskDetector] sample txn:', JSON.stringify(allTxns[0]));
  }

  const allCredit = allTxns.filter(t => t.type === 'Credit');
  const allDebit  = allTxns.filter(t => t.type === 'Debit');

  const income   = allCredit.filter(t => t.is_paid === true);
  const expenses = allDebit.filter(t => t.is_paid === true);
  const invoices = allCredit.filter(t => t.is_paid === false);
  const payables = allDebit.filter(t => t.is_paid === false);

  console.log('[riskDetector] income:', income.length, '| expenses:', expenses.length, '| invoices:', invoices.length, '| payables:', payables.length);

  const currentBalance = calculateCurrentBalance(income, expenses);
  console.log('[riskDetector] currentBalance:', currentBalance);

  const detected = [];

  const gap = detectCashFlowGap(currentBalance, income, expenses, today);
  if (gap) detected.push(gap);

  const overdue = detectOverdueInvoices(invoices, today);
  if (overdue) detected.push(overdue);

  const spike = detectExpenseSpike(expenses, today);
  if (spike) detected.push(spike);

  const decline = detectRevenueDecline(income, today);
  if (decline) detected.push(decline);

  const largePayable = detectLargePayable(payables, currentBalance, today);
  if (largePayable) detected.push(largePayable);

  console.log('[riskDetector] detected risks:', detected.length);

  return detected;
}

/* ========================= HELPERS ========================= */

function calculateCurrentBalance(income, expenses) {
  const inSum  = income.reduce((s, t) => s + Number(t.amount || 0), 0);
  const outSum = expenses.reduce((s, t) => s + Number(t.amount || 0), 0);
  return inSum - outSum;
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function weeksBetween(from, to) {
  const ms = to.getTime() - from.getTime();
  return Math.round(ms / (7 * 24 * 60 * 60 * 1000));
}

function formatDate(d) {
  return d.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
}

function monthKey(date) {
  const d = new Date(date);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function fmtRM(n) {
  return `RM ${Math.round(Number(n) || 0).toLocaleString('en-MY')}`;
}

/**
 * CRITICAL: MongoDB bsonType:'double' rejects JS integers.
 * Always wrap affected_amount with toDouble() before returning.
 * parseFloat on a whole number produces a JS float (BSON double).
 */
function toDouble(n) {
  return parseFloat(Number(n).toFixed(2));
}

/* ====================================================== *
 *                  1. CASH FLOW GAP                      *
 * ====================================================== */

function detectCashFlowGap(currentBalance, income, expenses, today) {
  const { forecastWeeks, lookbackWeeks, severity } = config.cashFlowGap;

  const cutoff = addDays(today, -lookbackWeeks * 7);
  const recentIn = income
    .filter((t) => new Date(t.txn_date) >= cutoff)
    .reduce((s, t) => s + Number(t.amount || 0), 0);
  const recentOut = expenses
    .filter((t) => new Date(t.txn_date) >= cutoff)
    .reduce((s, t) => s + Number(t.amount || 0), 0);
  const weeklyNet = (recentIn - recentOut) / lookbackWeeks;

  let projectedBalance = currentBalance;
  let gapWeek = null;
  let gapAmount = 0;
  let gapDate = null;

  for (let w = 1; w <= forecastWeeks; w++) {
    projectedBalance += weeklyNet;
    if (projectedBalance < 0 && gapWeek === null) {
      gapWeek = w;
      gapAmount = Math.abs(projectedBalance);
      gapDate = addDays(today, w * 7);
      break;
    }
  }

  if (gapWeek === null) return null;

  return {
    type: 'cash_flow_gap',
    category: 'Cash Flow',
    severity,
    title: `Cash Flow Gap in ${gapWeek} Weeks`,
    description: `Projected cash balance will reach -${fmtRM(gapAmount)} by ${formatDate(gapDate)}`,
    affected_amount: toDouble(gapAmount),          // ← double
    timeframe: `Week ${gapWeek} from now`,
    trigger_condition: `projected_balance < 0 within ${forecastWeeks} weeks`,
    detected_at: new Date(),                        // ← Date object
    status: 'active',
    supporting_data: {
      current_balance: toDouble(currentBalance),
      avg_weekly_net: toDouble(weeklyNet),
      gap_week: gapWeek,
      gap_date: gapDate.toISOString(),
      projected_balance_at_gap: toDouble(-gapAmount)
    }
  };
}

/* ====================================================== *
 *                2. OVERDUE INVOICES                     *
 * ====================================================== */

function detectOverdueInvoices(invoices, today) {
  const { highCountThreshold, highAmountThreshold } = config.overdueInvoices;

  const overdue = invoices.filter((inv) => {
    if (inv.is_paid) return false;
    if (!inv.due_date) return false;
    return new Date(inv.due_date) < today;
  });

  if (overdue.length === 0) return null;

  const totalAmount = overdue.reduce(
    (s, inv) => s + Number(inv.amount || 0),
    0
  );
  const oldestDays = Math.max(
    ...overdue.map((inv) =>
      Math.floor((today - new Date(inv.due_date)) / (24 * 60 * 60 * 1000))
    )
  );

  const severity =
    overdue.length >= highCountThreshold || totalAmount >= highAmountThreshold
      ? 'high'
      : 'medium';

  return {
    type: 'overdue_invoices',
    category: 'Receivables',
    severity,
    title: `${overdue.length} Overdue Invoice${overdue.length > 1 ? 's' : ''} Unpaid`,
    description: `${fmtRM(totalAmount)} outstanding across ${overdue.length} invoice${overdue.length > 1 ? 's' : ''} (oldest: ${oldestDays} days overdue)`,
    affected_amount: toDouble(totalAmount),         // ← double
    timeframe: 'Now',
    trigger_condition: 'unpaid invoices past due_date',
    detected_at: new Date(),                        // ← Date object
    status: 'active',
    supporting_data: {
      count: overdue.length,
      total_amount: toDouble(totalAmount),
      oldest_days_overdue: oldestDays,
      invoice_ids: overdue.map((i) => i._id)
    }
  };
}

/* ====================================================== *
 *                  3. EXPENSE SPIKE                      *
 * ====================================================== */

function detectExpenseSpike(expenses, today) {
  const { minIncreasePct, highSeverityPct } = config.expenseSpike;

  const thisMonthKey = monthKey(today);
  const lastMonthDate = new Date(today);
  lastMonthDate.setMonth(lastMonthDate.getMonth() - 1);
  const lastMonthKey = monthKey(lastMonthDate);

  const byMonth = {};
  for (const e of expenses) {
    const k = monthKey(e.txn_date);
    byMonth[k] = (byMonth[k] || 0) + Number(e.amount || 0);
  }

  const thisMonth = byMonth[thisMonthKey] || 0;
  const lastMonth = byMonth[lastMonthKey] || 0;

  if (lastMonth === 0) return null;

  const dayOfMonth = today.getDate();
  const daysInMonth = new Date(
    today.getFullYear(),
    today.getMonth() + 1,
    0
  ).getDate();
  const projectedThisMonth = (thisMonth / dayOfMonth) * daysInMonth;

  const increase = projectedThisMonth - lastMonth;
  const increasePct = increase / lastMonth;

  if (increasePct < minIncreasePct) return null;

  const severity = increasePct >= highSeverityPct ? 'high' : 'medium';

  return {
    type: 'expense_spike',
    category: 'Expenses',
    severity,
    title: `Operating Expenses Up ${Math.round(increasePct * 100)}% vs Last Month`,
    description: `${new Date(today).toLocaleString('en-GB', { month: 'long' })} expenses on pace to exceed ${new Date(lastMonthDate).toLocaleString('en-GB', { month: 'long' })} by ${fmtRM(increase)}`,
    affected_amount: toDouble(increase),            // ← double
    timeframe: 'This month',
    trigger_condition: `mom_expense_increase >= ${Math.round(minIncreasePct * 100)}%`,
    detected_at: new Date(),                        // ← Date object
    status: 'active',
    supporting_data: {
      this_month_actual: toDouble(thisMonth),
      this_month_projected: toDouble(projectedThisMonth),
      last_month: toDouble(lastMonth),
      increase_pct: Math.round(increasePct * 100)
    }
  };
}

/* ====================================================== *
 *                 4. REVENUE DECLINE                     *
 * ====================================================== */

function detectRevenueDecline(income, today) {
  const { minConsecutiveMonths, severity } = config.revenueDecline;

  const byMonth = {};
  for (const t of income) {
    const k = monthKey(t.txn_date);
    byMonth[k] = (byMonth[k] || 0) + Number(t.amount || 0);
  }

  const keys = Object.keys(byMonth).sort();
  const recent = keys.slice(-(minConsecutiveMonths + 1));
  if (recent.length < minConsecutiveMonths + 1) return null;

  let consecutive = 0;
  for (let i = recent.length - 1; i > 0; i--) {
    if (byMonth[recent[i]] < byMonth[recent[i - 1]]) {
      consecutive++;
    } else {
      break;
    }
  }

  if (consecutive < minConsecutiveMonths) return null;

  const firstMonthKey = recent[recent.length - 1 - consecutive];
  const lastMonthKey  = recent[recent.length - 1];
  const drop = byMonth[firstMonthKey] - byMonth[lastMonthKey];

  const firstMonthLabel = new Date(firstMonthKey + '-01').toLocaleString('en-GB', { month: 'short' });
  const lastMonthLabel  = new Date(lastMonthKey  + '-01').toLocaleString('en-GB', { month: 'short' });

  return {
    type: 'revenue_decline',
    category: 'Revenue',
    severity,
    title: `Revenue Declining ${consecutive} Consecutive Months`,
    description: `Monthly revenue dropped from ${fmtRM(byMonth[firstMonthKey])} (${firstMonthLabel}) to ${fmtRM(byMonth[lastMonthKey])} (${lastMonthLabel} projected)`,
    affected_amount: toDouble(drop),                // ← double
    timeframe: `Last ${consecutive} months`,
    trigger_condition: `revenue_decreased for ${minConsecutiveMonths}+ consecutive months`,
    detected_at: new Date(),                        // ← Date object
    status: 'active',
    supporting_data: {
      consecutive_months: consecutive,
      start_month: firstMonthKey,
      end_month: lastMonthKey,
      start_amount: toDouble(byMonth[firstMonthKey]),
      end_amount: toDouble(byMonth[lastMonthKey]),
      drop_amount: toDouble(drop)
    }
  };
}

/* ====================================================== *
 *                 5. LARGE PAYABLE                       *
 * ====================================================== */

function detectLargePayable(payables, currentBalance, today) {
  const { balanceRatio, severity } = config.largePayable;
  const { forecastWeeks } = config.cashFlowGap;
  const horizon = addDays(today, forecastWeeks * 7);

  const upcoming = payables.filter((p) => {
    if (p.is_paid) return false;
    if (!p.due_date) return false;
    const due = new Date(p.due_date);
    return due >= today && due <= horizon;
  });

  if (upcoming.length === 0) return null;

  const largest = upcoming.reduce((a, b) =>
    Number(a.amount) > Number(b.amount) ? a : b
  );

  const amount = Number(largest.amount);
  if (currentBalance <= 0) return null;
  if (amount / currentBalance < balanceRatio) return null;

  const dueDate = new Date(largest.due_date);
  const weeksAway = weeksBetween(today, dueDate);
  const vendor = largest.vendor_name || largest.vendor || largest.description || 'supplier';

  return {
    type: 'large_payable',
    category: 'Payables',
    severity,
    title: `Large Supplier Payment Due in ${weeksAway} Weeks`,
    description: `Annual agreement renewal payment of ${fmtRM(amount)} to ${vendor}`,
    affected_amount: toDouble(amount),              // ← double
    timeframe: `Week ${weeksAway} from now`,
    trigger_condition: `upcoming_payable >= ${Math.round(balanceRatio * 100)}% of balance`,
    detected_at: new Date(),                        // ← Date object
    status: 'active',
    supporting_data: {
      vendor,
      amount: toDouble(amount),
      due_date: dueDate.toISOString(),
      weeks_away: weeksAway,
      balance_at_detection: toDouble(currentBalance)
    }
  };
}

module.exports = {
  detectAll,
  detectCashFlowGap,
  detectOverdueInvoices,
  detectExpenseSpike,
  detectRevenueDecline,
  detectLargePayable
};

