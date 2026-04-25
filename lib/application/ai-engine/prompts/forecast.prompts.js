const FORECAST_SYSTEM_PROMPT = `
You are an expert financial analyst AI specialising in SME cash flow management.
Your job is to analyse cash flow forecasts and provide actionable insights.

Always respond in valid JSON with this exact structure:
{
  "summary": "string",
  "warnings": ["string"],
  "opportunities": ["string"],
  "recommended_actions": [
    {
      "action": "string",
      "estimated_impact_rm": number,
      "timeframe": "string"
    }
  ]
}
`.trim();

/**
 * Build the user prompt for forecast insight generation.
 * @param {Object} forecastData
 * @returns {string}
 */
function generateForecastInsightPrompt(forecastData) {
  const { current_balance, risk_summary, weekly_totals, projection_period_days } = forecastData;

  return `
Analyse the following ${projection_period_days}-day cash flow forecast for a Malaysian SME and provide insights.

Current Balance: RM ${current_balance}
Risk Level: ${risk_summary.risk_level}
At-Risk Days: ${risk_summary.at_risk_days}
Minimum Projected Balance: RM ${risk_summary.minimum_projected_balance}
Average Projected Balance: RM ${risk_summary.average_projected_balance}
Shortfall Date: ${risk_summary.projected_shortfall_date ?? 'None'}

Weekly Breakdown:
${weekly_totals.map((w) =>
  `  Week ${w.week}: Inflow RM${w.total_inflow}, Outflow RM${w.total_outflow}, Net RM${w.net_flow}, Balance RM${w.end_of_week_balance}`
).join('\n')}

Respond with JSON only. No preamble.
`.trim();
}

/**
 * Build the user prompt for optimisation recommendation generation.
 * @param {Object} forecastData
 * @param {Object} historicalPatterns
 * @returns {string}
 */
function generateOptimizationPrompt(forecastData, historicalPatterns) {
  return `
Given the following cash flow forecast and historical patterns, suggest optimisation strategies.

Risk Level: ${forecastData.risk_summary.risk_level}
Average Daily Inflow: RM ${historicalPatterns.avgDailyInflow}
Average Daily Outflow: RM ${historicalPatterns.avgDailyOutflow}
Peak Days: ${historicalPatterns.peakDays?.join(', ') ?? 'Unknown'}

Respond with JSON only containing an array of strategies:
{
  "strategies": [
    { "title": "string", "description": "string", "impact_rm": number, "timeframe": "string" }
  ]
}
`.trim();
}

module.exports = {
  FORECAST_SYSTEM_PROMPT,
  generateForecastInsightPrompt,
  generateOptimizationPrompt,
};