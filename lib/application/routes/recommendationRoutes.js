'use strict';

const express = require('express');
const router  = express.Router();

const recommendationRepo  = require('../../data/repositories/recommendationRepository');
const recommendationLogic = require('../logic/recommendation_logic');
const { generateRecommendations, buildFinancialSnapshot } =
  require('../ai-engine/recommendation_engine');
const businessRepo       = require('../../data/repositories/businessRepository');
const transactionRepo    = require('../../data/repositories/transactionRepository');
const riskAlertRepo      = require('../../data/repositories/riskAlertRepository');

function computeCurrentBalance(transactions) {
  return transactions.reduce((total, transaction) => {
    const amount = Number(transaction.amount) || 0;
    return transaction.type === 'Debit' ? total - amount : total + amount;
  }, 0);
}

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

router.post('/generate', async (req, res) => {
  try {
    const {
      businessId,
      riskId,
    } = req.body;

    if (!businessId) {
      return res.status(400).json({
        success: false,
        data:    null,
        error:   'businessId is required',
      });
    }

    const business = await businessRepo.getById(businessId);
    if (!business) {
      return res.status(404).json({
        success: false,
        data:    null,
        error:   'Business not found',
      });
    }

    const transactions = await transactionRepo.list(
      { business_id: businessId },
      { sort: { txn_date: -1 } },
    );

    if (transactions.length === 0) {
      return res.status(422).json({
        success: false,
        data:    null,
        error:   `No transactions found for business_id "${businessId}".`,
      });
    }

    const currentBalance = computeCurrentBalance(transactions);
    const activeRisks = await riskAlertRepo.listActiveByBusiness(businessId);
    const resolvedRiskId = riskId || activeRisks[0]?._id || businessId;

    const snapshot = buildFinancialSnapshot({
      transactions,
      businessName: business.name,
      businessType: business.industry || 'Business',
      currentBalance: Number(currentBalance),
    });

    const rawRecs = await generateRecommendations(snapshot);
    const docs    = recommendationLogic.buildRecommendationDocs(rawRecs, businessId, resolvedRiskId);

    if (docs.length === 0) {
      return res.status(422).json({
        success: false,
        data:    null,
        error:   'No valid recommendations could be built from Z.AI output',
      });
    }

    const saved   = await recommendationRepo.replaceAll(businessId, docs);
    const summary = recommendationLogic.calculateImpactSummary(saved);

    return res.json({ success: true, data: { summary, recommendations: saved }, error: null });

  } catch (err) {
    console.error('[POST /recommendations/generate]', err.message);
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

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

router.patch('/:id', async (req, res) => {
  try {
    const updates = { ...req.body };
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