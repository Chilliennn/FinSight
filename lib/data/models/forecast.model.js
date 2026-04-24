/**
 * data/models/forecast.model.js
 *
 * MongoDB Schema for Cash Flow Forecasts
 * Stores 8-week projections, risk metrics, and AI-generated insights.
 */

const mongoose = require('mongoose');

const forecastSchema = new mongoose.Schema(
  {
    // Business Reference
    business_id: {
      type: String,
      required: true,
      index: true,
    },

    // Financial Context
    current_balance: {
      type: Number,
      required: true, // RM at time of forecast generation
      min: 0,
    },
    projection_start_date: {
      type: String, // ISO 8601 date string (YYYY-MM-DD)
      required: true,
    },
    projection_period_days: {
      type: Number,
      default: 56, // 8 weeks
      min: 7,
      max: 365,
    },

    // Daily Projections (56 elements for 8-week forecast)
    daily_projections: [
      {
        date: String, // YYYY-MM-DD
        inflow: { type: Number, min: 0 },
        outflow: { type: Number, min: 0 },
        net_cash_flow: Number,
        projected_balance: { type: Number, min: 0 },
        is_at_risk: { type: Boolean, default: false }, // Balance < RM 5000
      },
    ],

    // Weekly Aggregates (8 weeks)
    weekly_totals: [
      {
        week: { type: Number, min: 1, max: 8 },
        total_inflow: { type: Number, min: 0 },
        total_outflow: { type: Number, min: 0 },
        net_flow: Number,
        end_of_week_balance: { type: Number, min: 0 },
      },
    ],

    // Risk Analysis
    risk_summary: {
      risk_level: {
        type: String,
        enum: ['Low', 'Medium', 'High'],
        required: true,
      },
      has_shortfall_risk: Boolean,
      projected_shortfall_date: String, // First date balance drops below RM 5000, or null
      at_risk_days: { type: Number, min: 0, max: 56 },
      minimum_projected_balance: { type: Number, min: 0 },
      average_projected_balance: { type: Number, min: 0 },
    },

    // AI-Generated Insights
    ai_insights: {
      summary: String, // 2-3 sentence overview
      warnings: [String], // Critical alerts
      opportunities: [String], // Positive opportunities
      recommended_actions: [
        {
          action: String,
          estimated_impact_rm: { type: Number, min: 0 },
          timeframe: String,
        },
      ],
    },

    // Lifecycle
    generated_at: {
      type: Date,
      default: Date.now,
      index: true,
    },
    expires_at: Date, // Auto-expire old forecasts (default: 30 days)
    is_active: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: false, // Manual control via generated_at
    collection: 'forecasts',
  },
);

// Compound index for efficient lookups
forecastSchema.index({ business_id: 1, is_active: 1, generated_at: -1 });
forecastSchema.index({ expires_at: 1 }, { expireAfterSeconds: 0 }); // TTL index

const Forecast = mongoose.model('Forecast', forecastSchema);

module.exports = Forecast;
