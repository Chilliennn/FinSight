'use strict';

const express = require('express');
const router = express.Router();
const transactionRepo = require('../../data/repositories/transactionRepository');
const transactionLogic = require('../logic/transaction_logic');

function ok(data) {
  return { success: true, data, error: null };
}

function fail(error) {
  return { success: false, data: null, error };
}

router.get('/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;
    const transactions = await transactionRepo.list(
      { business_id: businessId },
      { sort: { txn_date: -1 } },
    );

    const view = transactionLogic.buildTransactionView(transactions, {
      query: req.query.q,
      category: req.query.category,
      type: req.query.type,
      source: req.query.source,
    });

    return res.json(ok(view));
  } catch (err) {
    console.error('[GET /transactions/:businessId]', err.message);
    return res.status(500).json(fail(err.message || 'Failed to load transactions'));
  }
});

module.exports = router;
