/**
 * Risk Detector — Deterministic rules only.
 *
 * Per Manifesto §3: no AI code here.
 * Per Manifesto §5: no DB driver imports — all data comes via repositories.
 *
 * Five detectors matching the UI mockups:
 *   1. cash_flow_gap     — projected negative balance in forecast window
 *   2. overdue_invoices  — aggregate of unpaid invoices past due_date
 *   3. expense_spike     — MoM expense increase above threshold
 *   4. revenue_decline   — N+ consecutive months of falling revenue
 *   5. large_payable     — upcoming payable > X% of current balance
 *
 * Assumed transaction schema (Wayne's transactionRepository):
 *   { business_id, type: 'income'|'expense'|'invoice'|'payable', amount, txn_date,
 *     vendor_name?, is_paid?, due_date?, is_recurring? }
 */

const transactionRepo = require('../../data/repositories/transactionRepository');

/* ====================================================== *
 *         TUNABLE THRESHOLDS (edit here to adjust)       *
 * ====================================================== */

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

/* ====================================================== *
 *                    PUBLIC ENTRY POINT                  *
 * ====================================================== */

async function detectAll(businessId, opts = {}) {
  const today = opts.today ? new Date(opts.today) : new Date();

  const [income, expenses, invoices, payables] = await Promise.all([
    transactionRepo.list({ business_id: businessId, type: 'income' }),
    transactionRepo.list({ business_id: businessId, type: 'expense' }),
    transactionRepo.list({ business_id: businessId, type: 'invoice' }),
    transactionRepo.list({ business_id: businessId, type: 'payable' })
  ]);

  const currentBalance = calculateCurrentBalance(income, expenses);

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

  return detected;
}

/* ========================= HELPERS ========================= */

function calculateCurrentBalance(income, expenses) {
  const inSum = income.reduce((s, t) => s + Number(t.amount || 0), 0);
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
    affected_amount: Math.round(gapAmount),
    timeframe: `Week ${gapWeek} from now`,
    trigger_condition: `projected_balance < 0 within ${forecastWeeks} weeks`,
    supporting_data: {
      current_balance: Math.round(currentBalance),
      avg_weekly_net: Math.round(weeklyNet),
      gap_week: gapWeek,
      gap_date: gapDate.toISOString(),
      projected_balance_at_gap: Math.round(-gapAmount)
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
    affected_amount: Math.round(totalAmount),
    timeframe: 'Now',
    trigger_condition: 'unpaid invoices past due_date',
    supporting_data: {
      count: overdue.length,
      total_amount: Math.round(totalAmount),
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
    affected_amount: Math.round(increase),
    timeframe: 'This month',
    trigger_condition: `mom_expense_increase >= ${Math.round(minIncreasePct * 100)}%`,
    supporting_data: {
      this_month_actual: Math.round(thisMonth),
      this_month_projected: Math.round(projectedThisMonth),
      last_month: Math.round(lastMonth),
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
  const lastMonthKey = recent[recent.length - 1];
  const drop = byMonth[firstMonthKey] - byMonth[lastMonthKey];

  const firstMonthLabel = new Date(firstMonthKey + '-01').toLocaleString('en-GB', { month: 'short' });
  const lastMonthLabel = new Date(lastMonthKey + '-01').toLocaleString('en-GB', { month: 'short' });

  return {
    type: 'revenue_decline',
    category: 'Revenue',
    severity,
    title: `Revenue Declining ${consecutive} Consecutive Months`,
    description: `Monthly revenue dropped from ${fmtRM(byMonth[firstMonthKey])} (${firstMonthLabel}) to ${fmtRM(byMonth[lastMonthKey])} (${lastMonthLabel} projected)`,
    affected_amount: Math.round(drop),
    timeframe: `Last ${consecutive} months`,
    trigger_condition: `revenue_decreased for ${minConsecutiveMonths}+ consecutive months`,
    supporting_data: {
      consecutive_months: consecutive,
      start_month: firstMonthKey,
      end_month: lastMonthKey,
      start_amount: Math.round(byMonth[firstMonthKey]),
      end_amount: Math.round(byMonth[lastMonthKey]),
      drop_amount: Math.round(drop)
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
  const vendor = largest.vendor_name || 'supplier';

  return {
    type: 'large_payable',
    category: 'Payables',
    severity,
    title: `Large Supplier Payment Due in ${weeksAway} Weeks`,
    description: `Annual agreement renewal payment of ${fmtRM(amount)} to ${vendor}`,
    affected_amount: Math.round(amount),
    timeframe: `Week ${weeksAway} from now`,
    trigger_condition: `upcoming_payable >= ${Math.round(balanceRatio * 100)}% of balance`,
    supporting_data: {
      vendor,
      amount: Math.round(amount),
      due_date: dueDate.toISOString(),
      weeks_away: weeksAway,
      balance_at_detection: Math.round(currentBalance)
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

