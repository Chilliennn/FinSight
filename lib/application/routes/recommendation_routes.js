/**
 * application/routes/recommendation.routes.js
 *
 * The ONLY mediator between all layers. Sits alongside your other route files.
 *
 * ARCHITECTURE (per diagram):
 *   routes → logic          pure RM calculations; logic never calls back
 *   routes → ai_engine      Z.AI inference; financialSnapshot injected by routes
 *   routes → repositories   all DB reads/writes
 *
 *   logic        MUST NOT import repositories/ or ai_engine/
 *   ai_engine    MUST NOT import logic/
 *   repositories MUST NOT import logic/ or ai_engine/
 *
 * RELATIVE PATHS (from application/routes/):
 *   ../logic/         → application/logic/
 *   ../ai_engine/     → application/ai_engine/
 *   ../../data/database/repositories/ → data/database/repositories/
 */

const express = require('express');
const router  = express.Router();

const recommendationRepo   = require('../../data/database/repositories/recommendationRepository');
const recommendationLogic  = require('../logic/recommendation.logic');
const recommendationEngine = require('../ai_engine/recommendation.engine');

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/recommendations/:businessId
// Fetch all active recommendations + summary for a business.
//
// Flow: routes → repositories (fetch) → logic (calculate summary) → response
// ─────────────────────────────────────────────────────────────────────────────
router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;

    // routes → repositories: fetch active, non-expired docs sorted by rank
    const recommendations = await recommendationRepo.findByBusinessId(businessId);

    // routes → logic: pure RM summary calculation (logic receives data, never fetches)
    const summary = recommendationLogic.calculateImpactSummary(recommendations);

    return res.json({
      success: true,
      data:    { summary, recommendations },
      error:   null,
    });
  } catch (err) {
    console.error('[GET /recommendations/:businessId]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/recommendations/item/:id
// Fetch a single recommendation by _id.
//
// Flow: routes → repositories (getById) → response
// ─────────────────────────────────────────────────────────────────────────────
router.get('/item/:id', async (req, res) => {
  try {
    const rec = await recommendationRepo.getById(req.params.id);
    if (!rec) {
      return res.status(404).json({
        success: false, data: null, error: 'Recommendation not found',
      });
    }
    return res.json({ success: true, data: rec, error: null });
  } catch (err) {
    console.error('[GET /recommendations/item/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/recommendations/generate
// Trigger Z.AI to generate fresh recommendations from a financial snapshot.
// Body: { businessId, riskId, financialSnapshot }
//
// Flow: routes → ai_engine (Z.AI, snapshot injected by routes)
//        → logic (build DB docs — no DB access inside logic)
//        → repositories (replaceAll — soft-expires old, inserts new)
//        → logic (calculateImpactSummary — no DB access)
//        → response
// ─────────────────────────────────────────────────────────────────────────────
router.post('/generate', async (req, res) => {
  try {
    const { businessId, riskId, financialSnapshot } = req.body;

    if (!businessId || !riskId || !financialSnapshot) {
      return res.status(400).json({
        success: false,
        data:    null,
        error:   'businessId, riskId, and financialSnapshot are all required',
      });
    }

    // routes → ai_engine: inject snapshot; engine calls Z.AI, returns validated raw objects
    const rawRecs = await recommendationEngine.generateRecommendations(financialSnapshot);

    // routes → logic: transform raw Z.AI output into DB-ready documents (pure, no I/O)
    const docs = recommendationLogic.buildRecommendationDocs(rawRecs, businessId, riskId);

    if (docs.length === 0) {
      return res.status(422).json({
        success: false,
        data:    null,
        error:   'No valid recommendations could be built from Z.AI output',
      });
    }

    // routes → repositories: soft-expire old active recs, insert new batch
    const saved = await recommendationRepo.replaceAll(businessId, docs);

    // routes → logic: calculate RM summary on saved docs (pure, no I/O)
    const summary = recommendationLogic.calculateImpactSummary(saved);

    return res.json({
      success: true,
      data:    { summary, recommendations: saved },
      error:   null,
    });
  } catch (err) {
    console.error('[POST /recommendations/generate]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/recommendations/:id/action
// Mark a recommendation as actioned (status: 'active' → 'actioned').
//
// Flow: routes → repositories (markActioned) → response
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/action', async (req, res) => {
  try {
    const updated = await recommendationRepo.markActioned(req.params.id);
    if (!updated) {
      return res.status(404).json({
        success: false, data: null, error: 'Recommendation not found',
      });
    }
    return res.json({ success: true, data: updated, error: null });
  } catch (err) {
    console.error('[PATCH /recommendations/:id/action]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/recommendations/:id
// Generic partial update (e.g. dismiss).
// Body: any subset of updatable fields.
//
// Flow: routes → repositories (update) → response
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id', async (req, res) => {
  try {
    const updates = req.body;

    // Guard: prevent overwriting protected fields
    ['_id', 'business_id', 'risk_id', 'generated_at'].forEach(f => delete updates[f]);

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false, data: null, error: 'No updatable fields provided',
      });
    }

    const updated = await recommendationRepo.update(req.params.id, updates);
    if (!updated) {
      return res.status(404).json({
        success: false, data: null, error: 'Recommendation not found',
      });
    }
    return res.json({ success: true, data: updated, error: null });
  } catch (err) {
    console.error('[PATCH /recommendations/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/recommendations/:id
// Hard-delete a single recommendation.
//
// Flow: routes → repositories (remove) → response
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const result = await recommendationRepo.remove(req.params.id);
    if (result.deletedCount === 0) {
      return res.status(404).json({
        success: false, data: null, error: 'Recommendation not found',
      });
    }
    return res.json({ success: true, data: { deleted: true }, error: null });
  } catch (err) {
    console.error('[DELETE /recommendations/:id]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

module.exports = router;