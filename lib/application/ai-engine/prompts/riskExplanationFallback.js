/**
 * Fallback Explanation Templates — v1.0
 *
 * Used ONLY when Z.AI GLM 5.1 is unreachable. Each template uses the
 * real numbers from supporting_data.
 */

function fmtRM(n) {
  return `RM ${Math.round(Number(n) || 0).toLocaleString('en-MY')}`;
}

const templates = {
  cash_flow_gap: (d, risk) =>
    `At the current spending pace, your cash balance will turn negative by approximately ${fmtRM(
      Math.abs(d.projected_balance_at_gap || risk.affected_amount)
    )} in week ${d.gap_week}. If not addressed, you will be unable to cover operating expenses and may face payment defaults.`,

  overdue_invoices: (d) =>
    `You have ${d.count} invoices totalling ${fmtRM(
      d.total_amount
    )} that are past their due date (oldest is ${
      d.oldest_days_overdue
    } days overdue). Every extra day of delay increases collection risk and ties up working capital.`,

  expense_spike: (d) =>
    `Your expenses this month are on pace to reach ${fmtRM(
      d.this_month_projected
    )}, ${d.increase_pct}% higher than last month's ${fmtRM(
      d.last_month
    )}. If the trend continues, profit margins will compress significantly.`,

  revenue_decline: (d) =>
    `Monthly revenue has fallen for ${d.consecutive_months} consecutive months, from ${fmtRM(
      d.start_amount
    )} to ${fmtRM(
      d.end_amount
    )}. Sustained decline will erode your cash buffer and limit reinvestment capacity.`,

  large_payable: (d) =>
    `A payment of ${fmtRM(d.amount)} to ${
      d.vendor
    } is due in ${d.weeks_away} weeks — a large share of your current cash balance of ${fmtRM(
      d.balance_at_detection
    )}. Failing to plan for it could trigger a short-term cash squeeze.`
};

function generate(risk) {
  const data = risk.supporting_data || {};
  const template = templates[risk.type];
  if (!template) {
    return risk.description || 'Financial risk detected requiring attention.';
  }
  return template(data, risk);
}

module.exports = {
  generate,
  version: '1.0'
};