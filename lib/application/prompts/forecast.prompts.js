/**
 * application/prompts/forecast.prompts.js
 *
 * Z.AI Prompt Templates for Cash Flow Forecasting
 * Stores versioned prompts for forecast insight generation
 */

/**
 * System prompt for Z.AI to generate insightful forecast analysis.
 * Instructs the AI to provide Malaysian-context business advice.
 */
const FORECAST_SYSTEM_PROMPT = `You are FinSight AI, a financial advisor specialized in Malaysian SME cash flow management.

Your role:
- Analyze 8-week cash flow projections
- Identify risks and opportunities
- Provide actionable recommendations in Malaysian business context
- Quantify all impacts in RM (Malaysian Ringgit)

Response format: Always respond with valid JSON only, no markdown.
Use terminology familiar to Malaysian SME owners (cafes, pet stores, retail).
Consider seasonal factors, GST implications, and local payment cycles.`;

/**
 * User prompt template for generating forecast insights.
 * Receives financial data and generates structured analysis.
 *
 * @param {Object} forecastData - Complete forecast with projections and risk metrics
 * @returns {string} Formatted prompt for Z.AI
 */
function generateForecastInsightPrompt(forecastData) {
  const {
    current_balance,
    weekly_totals,
    daily_projections,
    risk_summary,
  } = forecastData;

  return `Analyze this 8-week cash flow forecast for a Malaysian SME:

**Current Financial Position:**
- Today's Cash Balance: RM${current_balance}
- Risk Level: ${risk_summary.risk_level}
- Minimum Projected Balance: RM${risk_summary.minimum_projected_balance}

**Weekly Breakdown:**
${weekly_totals.map((w) => `Week ${w.week}: Inflow RM${w.total_inflow} | Outflow RM${w.total_outflow} | Net RM${w.net_flow} | EOW Balance RM${w.end_of_week_balance}`).join('\n')}

**Risk Indicators:**
- Shortfall Risk: ${risk_summary.has_shortfall_risk ? 'YES' : 'NO'}
- At-Risk Days: ${risk_summary.at_risk_days}/56
- Average Balance: RM${risk_summary.average_projected_balance}

Please provide:
1. **Summary** (2-3 sentences): Overall forecast assessment
2. **Warnings** (list): Critical issues to address immediately
3. **Opportunities** (list): Actions to improve cash position
4. **Recommended Actions** (list): Specific RM-quantified steps

Respond in JSON format:
{
  "summary": "string",
  "warnings": ["string"],
  "opportunities": ["string"],
  "recommended_actions": [{"action": "string", "estimated_impact_rm": number, "timeframe": "string"}]
}`;
}

/**
 * Prompt for generating detailed cash flow optimization recommendations.
 */
function generateOptimizationPrompt(forecastData, historicalPatterns) {
  return `Based on this forecast and business patterns, suggest cash flow optimization strategies:

Forecast Summary:
- Current Balance: RM${forecastData.current_balance}
- 56-day Average Balance: RM${forecastData.risk_summary.average_projected_balance}
- Risk Level: ${forecastData.risk_summary.risk_level}

Historical Patterns:
- Average Daily Inflow: RM${historicalPatterns.avgDailyInflow}
- Average Daily Outflow: RM${historicalPatterns.avgDailyOutflow}
- Peak Days: ${historicalPatterns.peakDays.join(', ')}

Provide:
1. Receivables strategy to accelerate inflows
2. Payables strategy to smooth outflows
3. Buffer recommendations
4. Seasonal preparation tips

Format response as JSON with: {strategies: [{title, description, impact_rm}]}`;
}

module.exports = {
  FORECAST_SYSTEM_PROMPT,
  generateForecastInsightPrompt,
  generateOptimizationPrompt,
};
