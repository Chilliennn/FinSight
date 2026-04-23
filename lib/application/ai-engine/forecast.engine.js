/**
 * application/ai-engine/forecast.engine.js
 *
 * Z.AI Integration for Cash Flow Forecast Insights
 *
 * ARCHITECTURE RULES:
 *   - Called BY application/routes/forecast.routes.js ONLY
 *   - MUST NOT import repositories/ or logic/
 *   - Receives all data via function parameters (injected by routes)
 *   - Returns validated objects ready for logic or routes to save
 */

const prompts = require('../prompts/forecast.prompts');

/**
 * Call Z.AI to generate forecast insights.
 * Uses GLM 5.1 in json_mode for structured output.
 *
 * Flow:
 *   routes (has forecastData) → this function (calls Z.AI) → returns validated insights
 *
 * @param {Object} forecastData  - Complete forecast with projections and risk
 * @returns {Object}             - Validated AI insights {summary, warnings, opportunities, recommended_actions}
 *
 * @throws {Error} if Z.AI call fails or validation fails
 */
async function generateForecastInsights(forecastData) {
  // NOTE: This is a template for Z.AI integration.
  // Actual implementation requires:
  //   1. Z.AI SDK installation
  //   2. API key in environment
  //   3. Network call to Z.AI endpoint
  //
  // For now, returning mock structure that matches expected output
  // Production will use:
  //   const zhiyu = require('zhiyu-sdk');
  //   const response = await zhiyu.chat.completions.create({...})

  try {
    const systemPrompt = prompts.FORECAST_SYSTEM_PROMPT;
    const userPrompt = prompts.generateForecastInsightPrompt(forecastData);

    // MOCK: Replace with actual Z.AI call
    const mockInsights = {
      summary:
        'Based on historical patterns, your business shows stable cash flow with seasonal dips. The 8-week projection indicates sufficient liquidity with an average balance of RM ' +
        forecastData.risk_summary.average_projected_balance +
        '.',
      warnings: _generateMockWarnings(forecastData),
      opportunities: _generateMockOpportunities(forecastData),
      recommended_actions: _generateMockRecommendations(forecastData),
    };

    // Validate response structure
    _validateForecastInsights(mockInsights);

    return mockInsights;
  } catch (err) {
    console.error('[forecast.engine] Z.AI insight generation failed:', err.message);
    throw new Error(`Failed to generate forecast insights: ${err.message}`);
  }
}

/**
 * Generate optimization recommendations from forecast.
 *
 * @param {Object} forecastData          - Forecast with projections
 * @param {Object} historicalPatterns    - Historical transaction patterns
 * @returns {Object}                     - Optimization strategies
 */
async function generateOptimizationRecommendations(
  forecastData,
  historicalPatterns,
) {
  try {
    const optimizationPrompt = prompts.generateOptimizationPrompt(
      forecastData,
      historicalPatterns,
    );

    // MOCK: Replace with actual Z.AI call
    const mockOptimizations = {
      strategies: [
        {
          title: 'Early Collection Program',
          description:
            'Implement 2% early payment discount for invoices collected within 5 days',
          impact_rm: Math.round(
            forecastData.risk_summary.average_projected_balance * 0.05,
          ),
          timeframe: 'Immediate',
        },
        {
          title: 'Payables Staggering',
          description:
            'Negotiate 30-day terms with 3 key suppliers to align outflows with inflows',
          impact_rm: Math.round(
            forecastData.risk_summary.average_projected_balance * 0.08,
          ),
          timeframe: 'This week',
        },
      ],
    };

    return mockOptimizations;
  } catch (err) {
    console.error(
      '[forecast.engine] Optimization recommendation generation failed:',
      err.message,
    );
    throw err;
  }
}

/**
 * Validate Z.AI response structure.
 * Ensures all required fields are present and correctly typed.
 *
 * @param {Object} insights - Response to validate
 * @throws {Error} if validation fails
 */
function _validateForecastInsights(insights) {
  if (!insights || typeof insights !== 'object') {
    throw new Error('Insights must be an object');
  }

  if (
    !insights.summary ||
    typeof insights.summary !== 'string' ||
    insights.summary.trim().length === 0
  ) {
    throw new Error('summary is required and must be non-empty string');
  }

  if (!Array.isArray(insights.warnings)) {
    throw new Error('warnings must be an array');
  }

  if (!Array.isArray(insights.opportunities)) {
    throw new Error('opportunities must be an array');
  }

  if (!Array.isArray(insights.recommended_actions)) {
    throw new Error('recommended_actions must be an array');
  }

  insights.recommended_actions.forEach((action, idx) => {
    if (!action.action || typeof action.action !== 'string') {
      throw new Error(`Action ${idx}: action field required`);
    }
    if (
      !Number.isInteger(action.estimated_impact_rm) ||
      action.estimated_impact_rm < 0
    ) {
      throw new Error(`Action ${idx}: estimated_impact_rm must be positive integer`);
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK GENERATORS (Replace with real Z.AI calls in production)
// ─────────────────────────────────────────────────────────────────────────────

function _generateMockWarnings(forecastData) {
  const warnings = [];
  const { risk_summary } = forecastData;

  if (risk_summary.risk_level !== 'Low') {
    warnings.push(
      `${risk_summary.at_risk_days}-day liquidity risk period detected. Minimum balance: RM${risk_summary.minimum_projected_balance}`,
    );
  }

  const weeklyDeclines = forecastData.weekly_totals.filter(
    (w, idx, arr) => idx > 0 && w.end_of_week_balance < arr[idx - 1].end_of_week_balance,
  );

  if (weeklyDeclines.length > 0) {
    warnings.push(
      `Weeks ${weeklyDeclines.map((w) => w.week).join(', ')} show declining balances—monitor closely`,
    );
  }

  return warnings;
}

function _generateMockOpportunities(forecastData) {
  const opportunities = [];

  if (forecastData.risk_summary.average_projected_balance > 10000) {
    opportunities.push(
      'Strong cash position: Consider short-term investments or building emergency fund',
    );
  }

  if (forecastData.weekly_totals.some((w) => w.net_flow > 1000)) {
    opportunities.push(
      'Positive net weeks detected: Allocate surplus to debt repayment or business reinvestment',
    );
  }

  opportunities.push(
    'Use this forecast to negotiate better payment terms with suppliers',
  );

  return opportunities;
}

function _generateMockRecommendations(forecastData) {
  return [
    {
      action:
        'Establish receivables collection protocol—target 70% collection within 7 days',
      estimated_impact_rm: Math.round(
        forecastData.risk_summary.average_projected_balance * 0.10,
      ),
      timeframe: 'This week',
    },
    {
      action: 'Negotiate extended payment terms (30-days) with top 3 suppliers',
      estimated_impact_rm: Math.round(
        forecastData.risk_summary.average_projected_balance * 0.08,
      ),
      timeframe: 'Within 2 weeks',
    },
  ];
}

module.exports = {
  generateForecastInsights,
  generateOptimizationRecommendations,
};
