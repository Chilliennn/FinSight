'use strict';

const express = require('express');
const router = express.Router();
const transactionRepo = require('../../data/repositories/transactionRepository');

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

    return res.json(ok({ transactions }));
  } catch (err) {
    console.error('[GET /transactions/:businessId]', err.message);
    return res.status(500).json(fail(err.message || 'Failed to load transactions'));
  }
});

module.exports = router;
