const express = require('express');
const router = express.Router();
const businessRepo = require('../../data/repositories/businessRepository');

router.get('/:businessId', async (req, res) => {
  try {
    const business = await businessRepo.getById(req.params.businessId);
    if (!business) {
      return res.status(404).json({ success: false, data: null, error: 'Business not found' });
    }
    return res.json({ success: true, data: { business }, error: null });
  } catch (err) {
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

module.exports = router;
