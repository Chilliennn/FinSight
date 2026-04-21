/**
 * application/routes/recommendationRoutes.js
 *
 */

const express = require('express');
const router  = express.Router();

const recommendationRepo   = require('../../data/database/repositories/recommendationRepository');
const recommendationLogic  = require('../logic/recommendation.logic');
const recommendationEngine = require('../ai_engine/recommendation.engine');

router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;

    const recommendations = await recommendationRepo.findByBusinessId(businessId);
    const summary         = recommendationLogic.calculateImpactSummary(recommendations);

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

    // routes → ai_engine: call Z.AI, returns validated raw objects
    const rawRecs = await recommendationEngine.generateRecommendations(financialSnapshot);

    // routes → logic: transform raw Z.AI objects into DB-ready documents (pure, no I/O)
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

    // routes → logic: compute summary on the saved docs (pure, no I/O)
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

router.patch('/:id', async (req, res) => {
  try {
    const updates = req.body;

    // Guard: prevent overwriting protected fields
    ['_id', 'business_id', 'risk_id', 'generated_at'].forEach((f) => delete updates[f]);

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