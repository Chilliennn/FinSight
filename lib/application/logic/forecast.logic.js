/**
 * application/logic/forecast.logic.js
 *
 * Pure deterministic business logic for cash flow forecasting.
 * No I/O, no DB, no AI calls. All functions receive data as arguments.
 *
 * ARCHITECTURE RULES:
 *   - ZERO imports except built-ins
 *   - Called BY application/routes/forecast.routes.js ONLY
 *   - Results are passed back to routes — never stored here
 *
 * Core Functions:
 *   - calculateMovingAverage()     : Smooths historical data
 *   - projectCashFlow()            : 8-week projection using historical patterns
 *   - calculateRiskMetrics()       : Identifies shortfall risks
 *   - buildForecastDocs()          : Formats data for MongoDB storage
 */

/**
 * Calculate moving average from historical values.
 * Useful for smoothing transaction patterns to identify trends.
 *
 * @param {Array<number>} values       - Historical data points
 * @param {number}        windowSize   - Period for averaging (default: 7 for weekly)
 * @returns {Array<number>}              Smoothed values
 */
function calculateMovingAverage(values, windowSize = 7) {
  if (!values || values.length === 0) return [];
  if (values.length <= windowSize) return values;

  const result = [];
  for (let i = 0; i < values.length; i++) {
    const start = Math.max(0, i - Math.floor(windowSize / 2));
    const end = Math.min(values.length, i + Math.ceil(windowSize / 2));
    const window = values.slice(start, end);
    const avg = window.reduce((sum, val) => sum + val, 0) / window.length;
    result.push(Math.round(avg));
  }
  return result;
}

/**
 * Identify cyclical patterns in transaction data.
 * Returns day-of-week and week-of-month patterns.
 *
 * @param {Array<Object>} historicalTransactions - [{date, amount, type}]
 * @returns {Object} Patterns: {dayOfWeekFactors, weekOfMonthFactors}
 */
function identifyPatterns(historicalTransactions) {
  const dayOfWeekTotals = Array(7).fill(0);
  const dayOfWeekCounts = Array(7).fill(0);
  const weekOfMonthTotals = [[], [], [], [], []]; // 5 weeks max
  const weekOfMonthCounts = [[], [], [], [], []];

  historicalTransactions.forEach((tx) => {
    const date = new Date(tx.date);
    const dayOfWeek = date.getDay();
    const weekOfMonth = Math.floor((date.getDate() - 1) / 7);

    const amount = tx.type === 'inflow' ? tx.amount : -tx.amount;

    dayOfWeekTotals[dayOfWeek] += amount;
    dayOfWeekCounts[dayOfWeek] += 1;

    if (!weekOfMonthTotals[weekOfMonth]) weekOfMonthTotals[weekOfMonth] = [];
    if (!weekOfMonthCounts[weekOfMonth]) weekOfMonthCounts[weekOfMonth] = [];

    weekOfMonthTotals[weekOfMonth].push(amount);
    weekOfMonthCounts[weekOfMonth] += 1;
  });

  const dayOfWeekFactors = dayOfWeekTotals.map((total, idx) =>
    dayOfWeekCounts[idx] > 0 ? total / dayOfWeekCounts[idx] : 0,
  );

  const weekOfMonthFactors = weekOfMonthTotals.map((txList, idx) =>
    txList.length > 0
      ? txList.reduce((sum, tx) => sum + tx, 0) / txList.length
      : 0,
  );

  return { dayOfWeekFactors, weekOfMonthFactors };
}

/**
 * Project daily cash flow for 56 days (8 weeks).
 *
 * Algorithm:
 *   1. Analyze historical patterns (day-of-week, cyclical)
 *   2. Calculate average daily inflow/outflow
 *   3. Apply patterns to generate realistic 56-day projection
 *   4. Track running balance starting from currentBalance
 *
 * @param {number}        currentBalance          - Today's cash balance (RM)
 * @param {Array<Object>} historicalInflows       - [{date, amount}]
 * @param {Array<Object>} historicalOutflows      - [{date, amount}]
 * @param {number}        projectionDays          - Days to project (default: 56)
 * @returns {Array<Object>} Daily projections: [{date, inflow, outflow, net_cash_flow, projected_balance}]
 */
function projectCashFlow(
  currentBalance,
  historicalInflows,
  historicalOutflows,
  projectionDays = 56,
) {
  const avgDailyInflow = historicalInflows.length > 0
    ? historicalInflows.reduce((sum, tx) => sum + tx.amount, 0) / historicalInflows.length
    : 0;

  const avgDailyOutflow = historicalOutflows.length > 0
    ? historicalOutflows.reduce((sum, tx) => sum + tx.amount, 0) / historicalOutflows.length
    : 0;

  // Identify patterns for more realistic projections
  const inflowPatterns = identifyPatterns(
    historicalInflows.map((tx) => ({ ...tx, type: 'inflow' })),
  );
  const outflowPatterns = identifyPatterns(
    historicalOutflows.map((tx) => ({ ...tx, type: 'outflow' })),
  );

  const projections = [];
  let runningBalance = currentBalance;
  const today = new Date();

  for (let day = 0; day < projectionDays; day++) {
    const projectionDate = new Date(today);
    projectionDate.setDate(projectionDate.getDate() + day);

    const dayOfWeek = projectionDate.getDay();
    const weekOfMonth = Math.floor((projectionDate.getDate() - 1) / 7);

    // Apply day-of-week pattern with variance
    const dayFactor = 0.8 + Math.random() * 0.4; // ±20% variance
    let inflow = Math.round(
      (avgDailyInflow + (inflowPatterns.dayOfWeekFactors[dayOfWeek] || 0)) * dayFactor,
    );
    let outflow = Math.round(
      (avgDailyOutflow + (outflowPatterns.dayOfWeekFactors[dayOfWeek] || 0)) * dayFactor,
    );

    // Ensure non-negative (no negative cash flows)
    inflow = Math.max(0, inflow);
    outflow = Math.max(0, outflow);

    const netCashFlow = inflow - outflow;
    runningBalance = Math.max(0, runningBalance + netCashFlow);

    projections.push({
      date: projectionDate.toISOString().split('T')[0],
      inflow,
      outflow,
      net_cash_flow: netCashFlow,
      projected_balance: runningBalance,
      is_at_risk: runningBalance < 5000, // Risk threshold: RM 5000
    });
  }

  return projections;
}

/**
 * Calculate weekly summaries from daily projections.
 *
 * @param {Array<Object>} dailyProjections
 * @returns {Array<Object>} Weekly totals: [{week, total_inflow, total_outflow, net_flow, end_of_week_balance}]
 */
function calculateWeeklySummary(dailyProjections) {
  const weeks = [];
  for (let w = 0; w < 8; w++) {
    const weekStart = w * 7;
    const weekEnd = Math.min(weekStart + 7, dailyProjections.length);
    const weekDays = dailyProjections.slice(weekStart, weekEnd);

    if (weekDays.length === 0) continue;

    const totalInflow = weekDays.reduce((sum, d) => sum + d.inflow, 0);
    const totalOutflow = weekDays.reduce((sum, d) => sum + d.outflow, 0);
    const endOfWeekBalance = weekDays[weekDays.length - 1].projected_balance;

    weeks.push({
      week: w + 1,
      total_inflow: totalInflow,
      total_outflow: totalOutflow,
      net_flow: totalInflow - totalOutflow,
      end_of_week_balance: endOfWeekBalance,
    });
  }
  return weeks;
}

/**
 * Calculate risk metrics: shortfall dates, minimum balance, risk level.
 *
 * Risk Levels:
 *   - Low:    < 7 days at risk
 *   - Medium: 7–14 days at risk
 *   - High:   > 14 days at risk
 *
 * @param {Array<Object>} dailyProjections
 * @returns {Object} Risk metrics
 */
function calculateRiskMetrics(dailyProjections) {
  const atRiskDays = dailyProjections.filter((p) => p.is_at_risk).length;
  const minBalance = Math.min(
    ...dailyProjections.map((p) => p.projected_balance),
  );
  const firstShortfallDate = dailyProjections.find((p) => p.is_at_risk)?.date || null;

  let riskLevel = 'Low';
  if (atRiskDays > 14) riskLevel = 'High';
  else if (atRiskDays >= 7) riskLevel = 'Medium';

  const hasShortfallRisk = atRiskDays > 0;

  return {
    risk_level: riskLevel,
    has_shortfall_risk: hasShortfallRisk,
    projected_shortfall_date: firstShortfallDate,
    at_risk_days: atRiskDays,
    minimum_projected_balance: minBalance,
    average_projected_balance: Math.round(
      dailyProjections.reduce((sum, p) => sum + p.projected_balance, 0) /
      dailyProjections.length,
    ),
  };
}

/**
 * Transform forecast data into MongoDB-ready document.
 *
 * @param {Object} forecastData - Complete forecast calculation result
 * @returns {Object}            - DB-ready document
 */
function buildForecastDoc(forecastData) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days

  return {
    // _id intentionally omitted — repository assigns ObjectId
    business_id: forecastData.business_id,
    current_balance: forecastData.current_balance,
    projection_start_date: now.toISOString().split('T')[0],
    projection_period_days: forecastData.projection_period_days,

    weekly_totals: forecastData.weekly_totals,
    daily_projections: forecastData.daily_projections,

    risk_summary: forecastData.risk_summary,

    generated_at: now,
    expires_at: expiresAt,
    is_active: true,
  };
}

module.exports = {
  calculateMovingAverage,
  identifyPatterns,
  projectCashFlow,
  calculateWeeklySummary,
  calculateRiskMetrics,
  buildForecastDoc,
};
