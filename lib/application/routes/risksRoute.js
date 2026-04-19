/**
 * Risks Routes — "The Mediator" per Manifesto §3.
 *
 * Endpoints:
 *   GET  /:businessId            → list risks + score + counts for UI page load
 *   POST /:businessId/detect     → run full pipeline, persist, return fresh data
 *   POST /:id/acknowledge        → mark alert acknowledged
 *   POST /:id/resolve            → mark alert resolved
 *
 * Response contract: { success, data, error } per Manifesto §4.
 */

const express = require('express');
const router = express.Router();

const riskDetector = require('../logic/riskDetector');
const riskScorer = require('../logic/riskScoreCalculator');
const riskExplainer = require('../aiEngine/riskExplainer');
const riskAlertRepo = require('../../data/database/repositories/riskAlertRepository');

function ok(data) {
  return { success: true, data, error: null };
}
function fail(error) {
  return { success: false, data: null, error };
}

/* GET /api/risks/:businessId */
router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;

    // Optional business profile lookup — tolerates missing repo during early dev
    let business = null;
    try {
      const businessRepo = require('../../data/database/repositories/businessRepository');
      business = await businessRepo.getById(businessId);
    } catch (_) {
      // Business repo may not be wired yet — fall through to null
    }

    const [risks, counts] = await Promise.all([
      riskAlertRepo.listActiveByBusiness(businessId),
      riskAlertRepo.getSeverityCounts(businessId)
    ]);

    const score = riskScorer.calculateScore(risks);

    res.json(
      ok({
        business: {
          id: businessId,
          name: business?.name || 'Demo Business',
          type: business?.type || null
        },
        risks,
        counts,
        score,
        last_updated: risks.length > 0 ? risks[0].detected_at : null
      })
    );
  } catch (err) {
    console.error('[GET /risks] error:', err);
    res.status(500).json(fail(err.message || 'Failed to load risks'));
  }
});

/* POST /api/risks/:businessId/detect — the full pipeline */
router.post('/:businessId/detect', async (req, res) => {
  try {
    const { businessId } = req.params;

    // 1. Pure rule detection
    const detected = await riskDetector.detectAll(businessId);

    // 2. AI enrichment (parallel, with fallback on failure)
    const enriched = await riskExplainer.explainAll(detected);

    // 3. Persist via upsert
    for (const risk of enriched) {
      await riskAlertRepo.upsertByTypeAndBusiness(businessId, risk.type, risk);
    }

    // 4. Return fresh data
    const [risks, counts] = await Promise.all([
      riskAlertRepo.listActiveByBusiness(businessId),
      riskAlertRepo.getSeverityCounts(businessId)
    ]);
    const score = riskScorer.calculateScore(risks);

    res.json(
      ok({
        risks,
        counts,
        score,
        detected_count: enriched.length,
        last_updated: new Date()
      })
    );
  } catch (err) {
    console.error('[POST /risks/detect] error:', err);
    res.status(500).json(fail(err.message || 'Detection failed'));
  }
});

/* POST /api/risks/:id/resolve */
router.post('/:id/resolve', async (req, res) => {
  try {
    const updated = await riskAlertRepo.update(req.params.id, {
      status: 'resolved'
    });
    if (!updated) return res.status(404).json(fail('Risk not found'));
    res.json(ok(updated));
  } catch (err) {
    res.status(500).json(fail(err.message));
  }
});

module.exports = router;