/**
 * lib/application/routes/recommendationRoutes.js
 *
 *   Mode A — pre-built snapshot (testing / external triggers):
 *     { businessId, riskId, financialSnapshot }
 *
 *   Mode B — auto-build from transactions (normal production flow):
 *     { businessId, riskId, businessName, businessType, currentBalance }
 *
 *   Mode B fetches ALL transactions for businessId from MongoDB,
 *   calls buildFinancialSnapshot(), then drives the full Z.AI pipeline.
 *   Results are stored in the recommendations collection.
 */

'use strict';

const express = require('express');
const router  = express.Router();

const recommendationRepo  = require('../../data/repositories/recommendationRepository');
const recommendationLogic = require('../logic/recommendation_logic');
const { generateRecommendations, buildFinancialSnapshot } =
  require('../ai-engine/recommendation_engine');
const { getDb } = require('../../data/database/db');

// ── GET /recommendations/item/:id ─────────────────────────────────────────────
// Declared before /:businessId so "item" is not treated as a businessId
router.get('/item/:id', async (req, res) => {
  try {
    const rec = await recommendationRepo.getById(req.params.id);
    if (!rec) {
      return res.status(404).json({ success: false, data: null, error: 'Recommendation not found' });
    }
    return res.json({ success: true, data: rec, error: null });
  } catch (err) {
    console.error('[GET /recommendations/item/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ── GET /recommendations/:businessId ──────────────────────────────────────────
router.get('/:businessId', async (req, res) => {
  try {
    const recommendations = await recommendationRepo.findByBusinessId(req.params.businessId);
    const summary         = recommendationLogic.calculateImpactSummary(recommendations);
    return res.json({ success: true, data: { summary, recommendations }, error: null });
  } catch (err) {
    console.error('[GET /recommendations/:businessId]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ── POST /recommendations/generate ────────────────────────────────────────────
router.post('/generate', async (req, res) => {
  try {
    const {
      businessId,
      riskId,
      financialSnapshot,   // Mode A (optional)
      businessName,        // Mode B
      businessType,        // Mode B
      currentBalance,      // Mode B
    } = req.body;

    // ── Validation ───────────────────────────────────────────────────────────
    if (!businessId || !riskId) {
      return res.status(400).json({
        success: false,
        data:    null,
        error:   'businessId and riskId are required',
      });
    }

    let snapshot = financialSnapshot ?? null;

    // ── Mode B: fetch transactions from MongoDB → build snapshot ─────────────
    if (!snapshot) {
      if (!businessName || !businessType || currentBalance == null) {
        return res.status(400).json({
          success: false,
          data:    null,
          error:
            'Provide financialSnapshot (Mode A) OR businessName + businessType + ' +
            'currentBalance to auto-build from transactions (Mode B).',
        });
      }

      const db = await getDb();

      // Fetch all transactions for this business — engine handles date windowing
      const transactions = await db
        .collection('transactions')
        .find({ business_id: businessId })
        .sort({ txn_date: -1 })
        .toArray();

      if (transactions.length === 0) {
        return res.status(422).json({
          success: false,
          data:    null,
          error:   `No transactions found for business_id "${businessId}". ` +
                   `Seed transaction data first or check the business_id.`,
        });
      }

      snapshot = buildFinancialSnapshot({
        transactions,
        businessName,
        businessType,
        currentBalance: Number(currentBalance),
      });

      // Log snapshot summary for debugging (not the full payload)
      console.log(`[POST /generate] Mode B — ${transactions.length} txns → snapshot:`, {
        business:         businessName,
        avg_revenue:      snapshot.avg_monthly_revenue,
        avg_expenses:     snapshot.avg_monthly_expenses,
        overdue_invoices: snapshot.overdue_invoices.length,
        upcoming_bills:   snapshot.upcoming_expenses.length,
        cost_areas:       Object.keys(snapshot.cost_areas),
        cash_gap_risk:    snapshot.cash_gap_risk,
      });
    }

    // ── Call Z.AI → validate → build docs → store ─────────────────────────
    const rawRecs = await generateRecommendations(snapshot);
    const docs    = recommendationLogic.buildRecommendationDocs(rawRecs, businessId, riskId);

    if (docs.length === 0) {
      return res.status(422).json({
        success: false,
        data:    null,
        error:   'No valid recommendations could be built from Z.AI output',
      });
    }

    // Expire existing active recs for this business, insert the new batch
    const saved   = await recommendationRepo.replaceAll(businessId, docs);
    const summary = recommendationLogic.calculateImpactSummary(saved);

    console.log(
      `[POST /generate] Stored ${saved.length} recommendations for ${businessId}`,
      saved.map((r) => ({ rank: Number(r.rank), category: r.category, impact: r.projected_impact_value })),
    );

    return res.json({ success: true, data: { summary, recommendations: saved }, error: null });

  } catch (err) {
    console.error('[POST /recommendations/generate]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ── PATCH /recommendations/:id/action ─────────────────────────────────────────
router.patch('/:id/action', async (req, res) => {
  try {
    const updated = await recommendationRepo.markActioned(req.params.id);
    if (!updated) {
      return res.status(404).json({ success: false, data: null, error: 'Recommendation not found' });
    }
    return res.json({ success: true, data: updated, error: null });
  } catch (err) {
    console.error('[PATCH /recommendations/:id/action]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ── PATCH /recommendations/:id ────────────────────────────────────────────────
router.patch('/:id', async (req, res) => {
  try {
    const updates = { ...req.body };
    // Prevent overwriting immutable fields
    ['_id', 'business_id', 'risk_id', 'generated_at'].forEach((f) => delete updates[f]);

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, data: null, error: 'No updatable fields provided' });
    }

    const updated = await recommendationRepo.update(req.params.id, updates);
    if (!updated) {
      return res.status(404).json({ success: false, data: null, error: 'Recommendation not found' });
    }
    return res.json({ success: true, data: updated, error: null });
  } catch (err) {
    console.error('[PATCH /recommendations/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ── DELETE /recommendations/:id ───────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const result = await recommendationRepo.remove(req.params.id);
    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, data: null, error: 'Recommendation not found' });
    }
    return res.json({ success: true, data: { deleted: true }, error: null });
  } catch (err) {
    console.error('[DELETE /recommendations/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

module.exports = router;