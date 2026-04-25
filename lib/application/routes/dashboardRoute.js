const express = require('express');

const router = express.Router();

const businessRepo = require('../../data/repositories/businessRepository');
const forecastRepo = require('../../data/repositories/forecastRepository');
const recommendationRepo = require('../../data/repositories/recommendationRepository');
const riskAlertRepo = require('../../data/repositories/riskAlertRepository');
const transactionRepo = require('../../data/repositories/transactionRepository');

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function extractDate(doc) {
  const raw =
    doc.txn_date ??
    doc.transactionDate ??
    doc.date ??
    doc.created_at ??
    doc.createdAt ??
    null;

  if (!raw) return null;
  const parsed = raw instanceof Date ? raw : new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function classifyDirection(doc) {
  const token = String(doc.type ?? doc.direction ?? '').toLowerCase().trim();
  if (['credit', 'income', 'inflow', 'deposit', 'receivable'].includes(token)) {
    return 'inflow';
  }
  if (['debit', 'expense', 'outflow', 'withdrawal', 'payable'].includes(token)) {
    return 'outflow';
  }

  const amount = toNumber(doc.amount);
  if (amount > 0) return 'inflow';
  if (amount < 0) return 'outflow';
  return null;
}

function computeBalance(transactions) {
  return transactions.reduce((sum, tx) => {
    if (tx.direction === 'inflow') return sum + tx.amount;
    if (tx.direction === 'outflow') return sum - tx.amount;
    return sum;
  }, 0);
}

function monthWindow(date) {
  const start = new Date(date.getFullYear(), date.getMonth(), 1);
  const end = new Date(date.getFullYear(), date.getMonth() + 1, 1);
  return { start, end };
}

function sumByDirection(transactions, direction) {
  return transactions
    .filter((tx) => tx.direction === direction)
    .reduce((sum, tx) => sum + Math.abs(tx.amount), 0);
}

function formatSignedRm(value) {
  const rounded = Math.round(value);
  return `${rounded >= 0 ? '+' : '-'}RM ${Math.abs(rounded).toLocaleString()}`;
}

function startOfWeek(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = (day + 6) % 7;
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - diff);
  return d;
}

function shortDate(date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${date.getDate()} ${months[date.getMonth()]}`;
}

router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;

    const [business, riskList, riskCounts, recommendations, forecast] = await Promise.all([
      businessRepo.getById(businessId),
      riskAlertRepo.listActiveByBusiness(businessId),
      riskAlertRepo.getSeverityCounts(businessId),
      recommendationRepo.findByBusinessId(businessId),
      forecastRepo.findLatestByBusinessId(businessId),
    ]);

    if (!business) {
      return res.status(404).json({
        success: false,
        data: null,
        error: 'Business not found',
      });
    }

    const transactionDocs = await transactionRepo.list(
      { business_id: businessId },
      {
        sort: { txn_date: -1, created_at: -1, createdAt: -1 },
        limit: 500,
      },
    );

    const normalizedTransactions = transactionDocs
      .map((doc) => ({
        _id: doc._id,
        amount: Math.abs(toNumber(doc.amount)),
        direction: classifyDirection(doc),
        date: extractDate(doc),
        rawAmount: toNumber(doc.amount),
        counterparty:
          doc.counterparty ??
          doc.vendor_name ??
          doc.customer_name ??
          doc.description ??
          doc.reference ??
          'Transaction',
      }))
      .filter((tx) => tx.direction && tx.date)
      .sort((a, b) => b.date.getTime() - a.date.getTime());

    const today = new Date();
    const currentMonth = monthWindow(today);
    const previousMonth = monthWindow(new Date(today.getFullYear(), today.getMonth() - 1, 1));

    const inCurrentMonth = normalizedTransactions.filter(
      (tx) => tx.date >= currentMonth.start && tx.date < currentMonth.end,
    );
    const inPreviousMonth = normalizedTransactions.filter(
      (tx) => tx.date >= previousMonth.start && tx.date < previousMonth.end,
    );

    const monthlyRevenue = Math.round(sumByDirection(inCurrentMonth, 'inflow'));
    const monthlyExpenses = Math.round(sumByDirection(inCurrentMonth, 'outflow'));
    const previousRevenue = Math.round(sumByDirection(inPreviousMonth, 'inflow'));
    const previousExpenses = Math.round(sumByDirection(inPreviousMonth, 'outflow'));

    const currentBalanceFromBusiness =
      toNumber(business.current_balance) ||
      toNumber(business.balance) ||
      toNumber(business.cash_balance);

    const currentBalance = Math.round(
      currentBalanceFromBusiness !== 0
        ? currentBalanceFromBusiness
        : computeBalance(normalizedTransactions),
    );

    const balanceDelta = previousRevenue - previousExpenses;
    const revenueDelta = monthlyRevenue - previousRevenue;
    const expenseDelta = monthlyExpenses - previousExpenses;

    const outstandingInvoiceRisk = riskList
      .filter((risk) => {
        const token = `${risk.type ?? ''} ${risk.title ?? ''}`.toLowerCase();
        return token.includes('invoice') || token.includes('receivable');
      })
      .reduce((sum, risk) => sum + toNumber(risk.affected_amount), 0);

    const recommendationRows = recommendations.slice(0, 3).map((rec, index) => {
      const impactValue = toNumber(
        rec.projected_impact_value ?? rec.affected_amount,
      );
      const impactType = String(rec.impact_type || '').trim();

      let amountHint = impactValue >= 0 ? 'cash in' : 'cash out';
      if (impactType === 'Cash Buffer') amountHint = 'cash buffer';
      if (impactType === 'Cost Savings') amountHint = 'cost savings';
      if (impactType === 'Available Financing') amountHint = 'available financing';

      return {
        index: index + 1,
        title:
          rec.action_title ||
          rec.title ||
          rec.action ||
          'Recommendation',
        subtitle:
          rec.action_plan ||
          rec.timeframe ||
          rec.time_to_impact ||
          rec.reasoning ||
          rec.rationale ||
          'Action recommended',
        amount: formatSignedRm(impactValue),
        amount_value: Math.round(impactValue),
        amount_hint: amountHint,
      };
    });

    const riskRows = riskList.slice(0, 4).map((risk) => ({
      title: risk.title || risk.type || 'Risk alert',
      subtitle: `RM ${Math.abs(Math.round(toNumber(risk.affected_amount))).toLocaleString()} affected`,
      severity: (risk.severity || 'medium').toLowerCase(),
      affected_amount: Math.round(toNumber(risk.affected_amount)),
    }));

    const recentTransactions = normalizedTransactions.slice(0, 6).map((tx) => ({
      title: String(tx.counterparty),
      date: tx.date.toISOString().split('T')[0],
      amount: formatSignedRm(tx.direction === 'inflow' ? tx.amount : -tx.amount),
      direction: tx.direction,
      amount_value: tx.direction === 'inflow' ? tx.amount : -tx.amount,
    }));

    const shortfallDate = forecast?.risk_summary?.projected_shortfall_date || null;
    const minProjectedBalance = Math.round(
      toNumber(forecast?.risk_summary?.minimum_projected_balance),
    );

    const weeklyNetMap = new Map();
    for (const tx of normalizedTransactions) {
      const weekStart = startOfWeek(tx.date);
      const key = weekStart.toISOString().split('T')[0];
      const current = weeklyNetMap.get(key) || {
        date: weekStart,
        net: 0,
      };
      const delta = tx.direction === 'inflow' ? tx.amount : -tx.amount;
      current.net += delta;
      weeklyNetMap.set(key, current);
    }

    const historicalWeeks = Array.from(weeklyNetMap.values())
      .sort((a, b) => a.date.getTime() - b.date.getTime())
      .slice(-8);

    const historicalTotalNet = historicalWeeks.reduce((sum, w) => sum + w.net, 0);
    let runningHistoricalBalance = currentBalance - historicalTotalNet;
    const historicalTrend = historicalWeeks.map((w) => {
      runningHistoricalBalance += w.net;
      return {
        label: shortDate(w.date),
        balance: Math.round(runningHistoricalBalance),
      };
    });

    const forecastTrend = Array.isArray(forecast?.weekly_totals)
      ? forecast.weekly_totals.map((w) => ({
          label: `W${w.week}`,
          balance: Math.round(toNumber(w.end_of_week_balance)),
        }))
      : [];

    const alert = shortfallDate
      ? {
          title: 'Critical Alert: Cash flow gap projected soon',
          subtitle: `Projected balance of RM ${minProjectedBalance.toLocaleString()} by ${shortfallDate}`,
        }
      : {
          title: 'No immediate cash flow shortfall detected',
          subtitle: 'Current trajectory is stable based on the latest forecast window.',
        };

    return res.json({
      success: true,
      data: {
        as_of_date: today.toISOString().split('T')[0],
        business: {
          id: businessId,
          name: business.name || businessId,
          currency: business.currency || 'MYR',
        },
        kpis: {
          current_balance: currentBalance,
          current_balance_delta: balanceDelta,
          monthly_revenue: monthlyRevenue,
          monthly_revenue_delta: revenueDelta,
          monthly_expenses: monthlyExpenses,
          monthly_expenses_delta: expenseDelta,
          outstanding_invoices: Math.round(outstandingInvoiceRisk),
          outstanding_invoices_count: riskRows.filter((r) => r.title.toLowerCase().includes('invoice')).length,
        },
        alert,
        risk_summary: {
          total_active: riskList.length,
          counts: riskCounts,
          rows: riskRows,
        },
        recommendations: {
          total_active: recommendations.length,
          rows: recommendationRows,
        },
        recent_transactions: {
          total: normalizedTransactions.length,
          rows: recentTransactions,
        },
        trend: {
          historical: historicalTrend,
          forecast: forecastTrend,
        },
      },
      error: null,
    });
  } catch (err) {
    console.error('[GET /api/dashboard/:businessId]', err.message);
    return res.status(500).json({
      success: false,
      data: null,
      error: err.message,
    });
  }
});

module.exports = router;
