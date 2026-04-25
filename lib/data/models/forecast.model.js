// lib/data/models/forecast.model.js
// Native MongoDB collection schema descriptor for forecast documents.
// Kept as a standalone model file so app startup can validate the collection
// without using mongoose.

module.exports = {
  name: 'forecasts',
  schema: {
    bsonType: 'object',
    required: [
      '_id',
      'business_id',
      'current_balance',
      'projection_start_date',
      'projection_period_days',
      'daily_projections',
      'weekly_totals',
      'risk_summary',
      'generated_at',
      'expires_at',
      'is_active',
    ],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },
      current_balance: { bsonType: ['double', 'int'] },
      projection_start_date: { bsonType: 'string' },
      projection_period_days: { bsonType: ['double', 'int'] },
      daily_projections: {
        bsonType: 'array',
        items: {
          bsonType: 'object',
          required: ['date', 'inflow', 'outflow', 'net_cash_flow', 'projected_balance', 'is_at_risk'],
          properties: {
            date: { bsonType: 'string' },
            inflow: { bsonType: ['double', 'int'] },
            outflow: { bsonType: ['double', 'int'] },
            net_cash_flow: { bsonType: ['double', 'int'] },
            projected_balance: { bsonType: ['double', 'int'] },
            is_at_risk: { bsonType: 'bool' },
          },
        },
      },
      weekly_totals: {
        bsonType: 'array',
        items: {
          bsonType: 'object',
          required: ['week', 'total_inflow', 'total_outflow', 'net_flow', 'end_of_week_balance'],
          properties: {
            week: { bsonType: ['double', 'int'] },
            total_inflow: { bsonType: ['double', 'int'] },
            total_outflow: { bsonType: ['double', 'int'] },
            net_flow: { bsonType: ['double', 'int'] },
            end_of_week_balance: { bsonType: ['double', 'int'] },
          },
        },
      },
      risk_summary: {
        bsonType: 'object',
        required: [
          'risk_level',
          'has_shortfall_risk',
          'projected_shortfall_date',
          'at_risk_days',
          'minimum_projected_balance',
          'average_projected_balance',
        ],
        properties: {
          risk_level: { bsonType: 'string', enum: ['Low', 'Medium', 'High'] },
          has_shortfall_risk: { bsonType: 'bool' },
          projected_shortfall_date: { bsonType: ['string', 'null'] },
          at_risk_days: { bsonType: ['double', 'int'] },
          minimum_projected_balance: { bsonType: ['double', 'int'] },
          average_projected_balance: { bsonType: ['double', 'int'] },
        },
      },
      ai_insights: {
        bsonType: 'object',
        properties: {
          summary: { bsonType: 'string' },
          warnings: { bsonType: 'array', items: { bsonType: 'string' } },
          opportunities: { bsonType: 'array', items: { bsonType: 'string' } },
          recommended_actions: {
            bsonType: 'array',
            items: {
              bsonType: 'object',
              properties: {
                action: { bsonType: 'string' },
                estimated_impact_rm: { bsonType: ['double', 'int'] },
                timeframe: { bsonType: 'string' },
              },
            },
          },
        },
      },
      generated_at: { bsonType: 'date' },
      expires_at: { bsonType: 'date' },
      is_active: { bsonType: 'bool' },
    },
  },
};
