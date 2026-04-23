/**
 * application/routes/forecast.routes.js
 *
 * The ONLY mediator between all layers for cash flow forecasting.
 *
 * ARCHITECTURE:
 *   routes → logic          Pure RM calculations; logic never calls back
 *   routes → ai_engine      Z.AI inference; data injected by routes
 *   routes → repositories   All DB reads/writes
 *
 *   logic       MUST NOT import repositories/ or ai_engine/
 *   ai_engine   MUST NOT import logic/
 *   repositories MUST NOT import logic/ or ai_engine/
 */

const express = require('express');

const router = express.Router();

const forecastRepo = require('../../data/repositories/forecastRepository');
const forecastLogic = require('../logic/forecast.logic');
const forecastEngine = require('../ai-engine/forecast.engine');
const transactionRepo = require('../../data/repositories/transactionRepository'); // For historical data

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/forecast/:businessId
// Fetch current forecast + AI insights for a business.
//
// Flow: routes → repositories (fetch) → response
// ─────────────────────────────────────────────────────────────────────────────
router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;

    // routes → repositories: fetch latest active forecast
    const forecast = await forecastRepo.findLatestByBusinessId(businessId);

    if (!forecast) {
      return res.status(404).json({
        success: false,
        data: null,
        error: 'No forecast found. Please generate one first.',
      });
    }

    return res.json({
      success: true,
      data: forecast,
      error: null,
    });
  } catch (err) {
    console.error('[GET /forecast/:businessId]', err.message);
    return res.status(500).json({
      success: false,
      data: null,
      error: err.message,
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/forecast/generate
// Trigger forecast generation: fetch historical data → project → AI insights → save
//
// Body: { businessId, projectionDays (optional, default 56) }
//
// Flow:
//   1. routes → repositories (fetch historical inflows/outflows + balance)
//   2. routes → logic (calculate projections using historical patterns)
//   3. routes → logic (calculate risk metrics)
//   4. routes → ai_engine (generate insights)
//   5. routes → logic (build DB document)
//   6. routes → repositories (save forecast)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/generate', async (req, res) => {
  try {
    const { businessId, projectionDays = 56 } = req.body;

    if (!businessId) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'businessId is required',
      });
    }

    // Step 1: Fetch current balance and historical transactions
    const businessData = await forecastRepo.getBusinessFinancialSnapshot(businessId);

    if (!businessData) {
      return res.status(404).json({
        success: false,
        data: null,
        error: 'Business not found',
      });
    }

    const {
      current_balance: currentBalance,
      historical_inflows: historicalInflows,
      historical_outflows: historicalOutflows,
    } = businessData;

    // Step 2: routes → logic: Project cash flow using patterns
    const dailyProjections = forecastLogic.projectCashFlow(
      currentBalance,
      historicalInflows,
      historicalOutflows,
      projectionDays,
    );

    // Step 3: routes → logic: Calculate weekly summaries
    const weeklyTotals = forecastLogic.calculateWeeklySummary(dailyProjections);

    // Step 4: routes → logic: Calculate risk metrics
    const riskSummary = forecastLogic.calculateRiskMetrics(dailyProjections);

    // Step 5: Build forecast data object for AI engine
    const forecastData = {
      business_id: businessId,
      current_balance: currentBalance,
      projection_period_days: projectionDays,
      daily_projections: dailyProjections,
      weekly_totals: weeklyTotals,
      risk_summary: riskSummary,
    };

    // Step 6: routes → ai_engine: Generate AI insights (injected data)
    let aiInsights = {};
    try {
      aiInsights = await forecastEngine.generateForecastInsights(forecastData);
    } catch (aiErr) {
      console.warn('[forecast.routes] AI insights generation warning:', aiErr.message);
      // Don't fail if AI fails — provide default insights
      aiInsights = {
        summary: 'Forecast generated. AI insights unavailable at this time.',
        warnings: [],
        opportunities: [],
        recommended_actions: [],
      };
    }

    // Step 7: routes → logic: Build DB-ready document
    const forecastDoc = forecastLogic.buildForecastDoc(forecastData);
    forecastDoc.ai_insights = aiInsights;

    // Step 8: routes → repositories: Save to database
    const savedForecast = await forecastRepo.upsertForecast(businessId, forecastDoc);

    return res.json({
      success: true,
      data: savedForecast,
      error: null,
    });
  } catch (err) {
    console.error('[POST /forecast/generate]', err.message);
    return res.status(500).json({
      success: false,
      data: null,
      error: err.message,
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/forecast/report/:forecastId
// Fetch detailed forecast report with all projections.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/report/:forecastId', async (req, res) => {
  try {
    const { forecastId } = req.params;

    const forecast = await forecastRepo.getById(forecastId);
    if (!forecast) {
      return res.status(404).json({
        success: false,
        data: null,
        error: 'Forecast not found',
      });
    }

    return res.json({
      success: true,
      data: forecast,
      error: null,
    });
  } catch (err) {
    console.error('[GET /forecast/report/:forecastId]', err.message);
    return res.status(500).json({
      success: false,
      data: null,
      error: err.message,
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/forecast/optimize
// Generate optimization recommendations based on current forecast.
//
// Body: { businessId }
//
// Flow:
//   routes → repositories (fetch forecast + historical patterns)
//   → ai_engine (generate optimization strategies)
//   → response
// ─────────────────────────────────────────────────────────────────────────────
router.post('/optimize', async (req, res) => {
  try {
    const { businessId } = req.body;

    if (!businessId) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'businessId is required',
      });
    }

    // Fetch latest forecast
    const forecast = await forecastRepo.findLatestByBusinessId(businessId);
    if (!forecast) {
      return res.status(404).json({
        success: false,
        data: null,
        error: 'No forecast available. Please generate one first.',
      });
    }

    // Fetch historical patterns
    const businessData = await forecastRepo.getBusinessFinancialSnapshot(businessId);

    const historicalPatterns = {
      avgDailyInflow: businessData.historical_inflows.length > 0
        ? Math.round(
          businessData.historical_inflows.reduce((sum, tx) => sum + tx.amount, 0) /
          businessData.historical_inflows.length,
        )
        : 0,
      avgDailyOutflow: businessData.historical_outflows.length > 0
        ? Math.round(
          businessData.historical_outflows.reduce((sum, tx) => sum + tx.amount, 0) /
          businessData.historical_outflows.length,
        )
        : 0,
      peakDays: ['Monday', 'Tuesday'], // TODO: Calculate from data
    };

    // Generate optimization recommendations
    const optimizations = await forecastEngine.generateOptimizationRecommendations(
      forecast,
      historicalPatterns,
    );

    return res.json({
      success: true,
      data: optimizations,
      error: null,
    });
  } catch (err) {
    console.error('[POST /forecast/optimize]', err.message);
    return res.status(500).json({
      success: false,
      data: null,
      error: err.message,
    });
  }
});

module.exports = router;
