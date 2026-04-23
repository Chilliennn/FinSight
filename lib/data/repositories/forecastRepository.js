/**
 * data/repositories/forecastRepository.js
 *
 * The "Librarian" for all forecast database operations.
 * ONLY place allowed to perform DB queries for forecasts.
 *
 * ARCHITECTURE RULES:
 *   - MUST NOT import logic/ or ai_engine/ — they call this, not vice versa
 *   - Called BY application/routes/ ONLY
 *   - Returns plain objects (no business logic inside)
 */

const Forecast = require('../models/forecast.model');

/**
 * Fetch latest active forecast for a business.
 *
 * @param {string} businessId
 * @returns {Object|null} Latest forecast or null if not found
 */
async function findLatestByBusinessId(businessId) {
  try {
    const forecast = await Forecast.findOne(
      {
        business_id: businessId,
        is_active: true,
        expires_at: { $gt: new Date() }, // Not expired
      },
      {},
      { sort: { generated_at: -1 } },
    );

    return forecast ? forecast.toObject() : null;
  } catch (err) {
    console.error('[forecastRepository.findLatestByBusinessId]', err.message);
    throw err;
  }
}

/**
 * Fetch forecast by ID.
 *
 * @param {string} forecastId - MongoDB _id
 * @returns {Object|null} Forecast or null
 */
async function getById(forecastId) {
  try {
    const forecast = await Forecast.findById(forecastId);
    return forecast ? forecast.toObject() : null;
  } catch (err) {
    console.error('[forecastRepository.getById]', err.message);
    throw err;
  }
}

/**
 * Save or update forecast for a business.
 * Marks previous active forecasts as inactive.
 *
 * @param {string} businessId
 * @param {Object} forecastData - Document to insert/update
 * @returns {Object} Saved forecast
 */
async function upsertForecast(businessId, forecastData) {
  try {
    // Mark previous active forecasts as inactive
    await Forecast.updateMany(
      { business_id: businessId, is_active: true },
      { $set: { is_active: false } },
    );

    // Insert new forecast
    const forecast = new Forecast({
      ...forecastData,
      business_id: businessId,
    });

    await forecast.save();
    return forecast.toObject();
  } catch (err) {
    console.error('[forecastRepository.upsertForecast]', err.message);
    throw err;
  }
}

/**
 * Fetch financial snapshot for forecast generation.
 * Returns current balance + historical inflows/outflows for pattern analysis.
 *
 * @param {string} businessId
 * @returns {Object} {current_balance, historical_inflows, historical_outflows}
 */
async function getBusinessFinancialSnapshot(businessId) {
  try {
    // TODO: Fetch from transaction repository
    // This is a placeholder — integrate with transactionRepository
    // to get:
    //   - Current balance from latest transaction/business record
    //   - Historical inflows (transactions with type: 'inflow', last 90 days)
    //   - Historical outflows (transactions with type: 'outflow', last 90 days)

    return {
      current_balance: 15000, // Placeholder
      historical_inflows: [
        { date: '2026-04-01', amount: 3500 },
        { date: '2026-04-02', amount: 2800 },
        { date: '2026-04-03', amount: 4200 },
        // ... more transactions
      ],
      historical_outflows: [
        { date: '2026-04-01', amount: 1200 },
        { date: '2026-04-02', amount: 800 },
        { date: '2026-04-03', amount: 1100 },
        // ... more transactions
      ],
    };
  } catch (err) {
    console.error('[forecastRepository.getBusinessFinancialSnapshot]', err.message);
    throw err;
  }
}

/**
 * Fetch all forecasts for a business (for history/auditing).
 *
 * @param {string} businessId
 * @param {number} limit - Max results (default: 12, ~3 months of weekly forecasts)
 * @returns {Array} Historical forecasts
 */
async function findHistoryByBusinessId(businessId, limit = 12) {
  try {
    const forecasts = await Forecast.find(
      { business_id: businessId },
      {},
      {
        sort: { generated_at: -1 },
        limit,
        lean: true,
      },
    );

    return forecasts;
  } catch (err) {
    console.error('[forecastRepository.findHistoryByBusinessId]', err.message);
    throw err;
  }
}

/**
 * Delete forecast by ID.
 *
 * @param {string} forecastId
 * @returns {Object} DeleteResult
 */
async function deleteById(forecastId) {
  try {
    const result = await Forecast.deleteOne({ _id: forecastId });
    return result;
  } catch (err) {
    console.error('[forecastRepository.deleteById]', err.message);
    throw err;
  }
}

module.exports = {
  findLatestByBusinessId,
  getById,
  upsertForecast,
  getBusinessFinancialSnapshot,
  findHistoryByBusinessId,
  deleteById,
};
