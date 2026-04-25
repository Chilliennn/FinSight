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

const { getDb } = require('../database/db');
const { ObjectId } = require('mongodb');
const forecastModel = require('../models/forecast.model');

const FORECASTS_COLLECTION = forecastModel.name;
const BUSINESSES_COLLECTION = 'businesses';
const TRANSACTIONS_COLLECTION = 'transactions';
const FINANCIAL_RECORDS_COLLECTION = 'financial_records';
const HISTORY_WINDOW_DAYS = 90;

function _businessFilter(businessId) {
  return {
    $or: [
      { _id: businessId },
      { business_id: businessId },
      { businessId },
    ],
  };
}

function _toNumber(value) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? normalized : 0;
}

function _extractDate(doc) {
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

function _directionFromType(type) {
  const token = String(type ?? '').toLowerCase().trim();
  if (!token) return null;

  if (['inflow', 'income', 'credit', 'deposit', 'receivable'].includes(token)) {
    return 'inflow';
  }

  if (['outflow', 'expense', 'debit', 'withdrawal', 'payable'].includes(token)) {
    return 'outflow';
  }

  return null;
}

function _classifyDirection(doc) {
  const byDirection = _directionFromType(doc.direction);
  if (byDirection) return byDirection;

  const byType = _directionFromType(doc.type);
  if (byType) return byType;

  const byRecordType = _directionFromType(doc.recordType);
  if (byRecordType) return byRecordType;

  const amount = _toNumber(doc.amount);
  if (amount > 0) return 'inflow';
  if (amount < 0) return 'outflow';
  return null;
}

function _mapHistoryDoc(doc) {
  return {
    date: doc.date.toISOString().split('T')[0],
    amount: Math.abs(Math.round(_toNumber(doc.amount))),
  };
}

function _normalizeForecastDocument(doc) {
  return doc ? { ...doc } : null;
}

function _buildForecastQuery(businessId) {
  return {
    business_id: businessId,
    is_active: true,
    expires_at: { $gt: new Date() },
  };
}

/**
 * Fetch latest active forecast for a business.
 *
 * @param {string} businessId
 * @returns {Object|null} Latest forecast or null if not found
 */
async function findLatestByBusinessId(businessId) {
  try {
    const db = await getDb();
    const forecast = await db.collection(FORECASTS_COLLECTION).findOne(
      _buildForecastQuery(businessId),
      { sort: { generated_at: -1 } },
    );

    return _normalizeForecastDocument(forecast);
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
    const db = await getDb();
    const forecast = await db.collection(FORECASTS_COLLECTION).findOne({ _id: forecastId });
    return _normalizeForecastDocument(forecast);
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
    const db = await getDb();

    await db.collection(FORECASTS_COLLECTION).updateMany(
      { business_id: businessId, is_active: true },
      { $set: { is_active: false } },
    );

    const document = {
      ...forecastData,
      business_id: businessId,
      _id: forecastData._id || new ObjectId().toHexString(),
    };

    await db.collection(FORECASTS_COLLECTION).insertOne(document);
    return _normalizeForecastDocument(document);
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
    const db = await getDb();
    const now = new Date();
    const cutoffDate = new Date(now);
    cutoffDate.setDate(now.getDate() - HISTORY_WINDOW_DAYS);

    const business = await db
      .collection(BUSINESSES_COLLECTION)
      .findOne(_businessFilter(businessId));

    if (!business) {
      return null;
    }

    const transactionDocs = await db
      .collection(TRANSACTIONS_COLLECTION)
      .find(_businessFilter(businessId), {
        projection: {
          amount: 1,
          type: 1,
          direction: 1,
          recordType: 1,
          txn_date: 1,
          transactionDate: 1,
          date: 1,
          created_at: 1,
          createdAt: 1,
        },
      })
      .toArray();

    const financialRecordDocs = transactionDocs.length === 0
      ? await db
          .collection(FINANCIAL_RECORDS_COLLECTION)
          .find(_businessFilter(businessId), {
            projection: {
              amount: 1,
              type: 1,
              direction: 1,
              recordType: 1,
              txn_date: 1,
              transactionDate: 1,
              date: 1,
              created_at: 1,
              createdAt: 1,
            },
          })
          .toArray()
      : [];

    const sourceDocs = transactionDocs.length > 0 ? transactionDocs : financialRecordDocs;

    const normalized = sourceDocs
      .map((doc) => {
        const amount = _toNumber(doc.amount);
        const date = _extractDate(doc);
        const direction = _classifyDirection(doc);
        return { amount, date, direction };
      })
      .filter((doc) => doc.direction && doc.date && doc.date <= now)
      .sort((a, b) => a.date.getTime() - b.date.getTime());

    const currentBalanceFromTransactions = normalized.reduce((sum, doc) => {
      if (doc.direction === 'inflow') return sum + Math.abs(doc.amount);
      if (doc.direction === 'outflow') return sum - Math.abs(doc.amount);
      return sum;
    }, 0);

    const fallbackBusinessBalance =
      _toNumber(business.current_balance) ||
      _toNumber(business.balance) ||
      _toNumber(business.cash_balance) ||
      0;

    const currentBalance = normalized.length > 0
      ? Math.max(0, Math.round(currentBalanceFromTransactions))
      : Math.max(0, Math.round(fallbackBusinessBalance));

    const historicalWindow = normalized.filter((doc) => doc.date >= cutoffDate);
    const historicalInflows = historicalWindow
      .filter((doc) => doc.direction === 'inflow')
      .map(_mapHistoryDoc);
    const historicalOutflows = historicalWindow
      .filter((doc) => doc.direction === 'outflow')
      .map(_mapHistoryDoc);

    return {
      current_balance: currentBalance,
      historical_inflows: historicalInflows,
      historical_outflows: historicalOutflows,
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
