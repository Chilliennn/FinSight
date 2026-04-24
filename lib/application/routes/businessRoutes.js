const express = require('express');
const router = express.Router();
const businessRepo = require('../../data/repositories/businessRepository');

router.post('/', async (req, res) => {
  try {
    const {
      _id,
      name,
      industry,
      safety_buffer_threshold,
      currency,
    } = req.body;

    if (!_id || typeof _id !== 'string' || !_id.trim()) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Business ID is required. Expected 3-64 characters using letters, numbers, _ or -.',
      });
    }

    if (!/^[a-zA-Z0-9_-]{3,64}$/.test(_id.trim())) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Business ID is invalid. Expected 3-64 characters using letters, numbers, _ or -.',
      });
    }

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Business Name is required. Expected a non-empty string.',
      });
    }

    if (!currency || typeof currency !== 'string' || !currency.trim()) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Currency is required. Expected a 3-letter code such as MYR or SGD.',
      });
    }

    if (!/^[A-Za-z]{3}$/.test(currency.trim())) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Currency is invalid. Expected a 3-letter code such as MYR or SGD.',
      });
    }

    if (
      safety_buffer_threshold != null &&
      (!Number.isFinite(Number(safety_buffer_threshold)) ||
        Number(safety_buffer_threshold) < 0)
    ) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'Safety Buffer Threshold (RM) is invalid. Expected a number greater than or equal to 0.',
      });
    }

    const businessId = _id.trim();
    const existing = await businessRepo.getById(businessId);
    if (existing) {
      return res.status(409).json({
        success: false,
        data: null,
        error: 'Business ID already exists. Please use a different Business ID.',
      });
    }

    const created = await businessRepo.create({
      _id: businessId,
      name: name.trim(),
      industry: typeof industry === 'string' ? industry.trim() : '',
      currency: currency.trim().toUpperCase(),
      ...(safety_buffer_threshold != null
          ? { safety_buffer_threshold: Number(safety_buffer_threshold) }
          : {}),
    });

    return res.status(201).json({ success: true, data: { business: created }, error: null });
  } catch (err) {
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

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

router.patch('/:businessId', async (req, res) => {
  try {
    const id = req.params.businessId;
    const existing = await businessRepo.getById(id);
    if (!existing) {
      return res.status(404).json({ success: false, data: null, error: 'Business not found' });
    }

    const updates = { ...req.body };
    delete updates._id;
    delete updates.created_at;

    if (updates.safety_buffer_threshold != null) {
      if (
        !Number.isFinite(Number(updates.safety_buffer_threshold)) ||
        Number(updates.safety_buffer_threshold) < 0
      ) {
        return res.status(400).json({
          success: false,
          data: null,
          error: 'Safety Buffer Threshold (RM) is invalid. Expected a number greater than or equal to 0.',
        });
      }
      updates.safety_buffer_threshold = Number(updates.safety_buffer_threshold);
    }

    if (updates.currency != null) {
      if (typeof updates.currency !== 'string' || !/^[A-Za-z]{3}$/.test(updates.currency.trim())) {
        return res.status(400).json({
          success: false,
          data: null,
          error: 'Currency is invalid. Expected a 3-letter code such as MYR or SGD.',
        });
      }
      updates.currency = updates.currency.trim().toUpperCase();
    }

    if (updates.name != null) {
      if (typeof updates.name !== 'string' || !updates.name.trim()) {
        return res.status(400).json({
          success: false,
          data: null,
          error: 'Business Name is invalid. Expected a non-empty string.',
        });
      }
      updates.name = updates.name.trim();
    }

    if (updates.industry != null && typeof updates.industry === 'string') {
      updates.industry = updates.industry.trim();
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, data: null, error: 'No updatable fields provided' });
    }

    const updated = await businessRepo.update(id, updates);
    return res.json({ success: true, data: { business: updated }, error: null });
  } catch (err) {
    return res.status(500).json({ success: false, data: null, error: err.message });
  }
});

module.exports = router;
