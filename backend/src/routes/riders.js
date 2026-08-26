const express = require('express');
const router = express.Router();
const Rider = require('../models/Rider');

router.get('/', async (req, res) => {
  try {
    const riders = await Rider.find({ isActive: true });
    res.json(riders);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get('/earnings/:id', async (req, res) => {
  try {
    const rider = await Rider.findById(req.params.id);
    if (!rider) return res.status(404).json({ message: 'Rider not found' });
    res.json({ totalEarnings: rider.totalEarnings, paymentHistory: rider.paymentHistory });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.put('/:id/location', async (req, res) => {
  try {
    const rider = await Rider.findByIdAndUpdate(req.params.id, { currentLocation: req.body }, { new: true });
    res.json(rider);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;
