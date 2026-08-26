const express = require('express');
const router = express.Router();
const Shop = require('../models/Shop');

router.get('/', async (req, res) => {
  try {
    const shops = await Shop.find({ isActive: true });
    res.json(shops);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const shop = await Shop.findById(req.params.id);
    if (!shop) return res.status(404).json({ message: 'Shop not found' });
    res.json(shop);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;
