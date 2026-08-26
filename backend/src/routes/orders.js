const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const Shop = require('../models/Shop');

router.get('/', async (req, res) => {
  try {
    const orders = await Order.find().populate('shopId', 'name logo').sort({ createdAt: -1 });
    res.json(orders);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { customerId, shopId, items, totalAmount, deliveryAddress } = req.body;
    const order = new Order({ customerId, shopId, items, totalAmount, deliveryAddress, status: 'pending' });
    await order.save();
    res.status(201).json(order);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const order = await Order.findById(req.params.id).populate('shopId', 'name logo address');
    res.json(order);
  } catch (e) {
    res.status(404).json({ message: 'Order not found' });
  }
});

router.put('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findByIdAndUpdate(req.params.id, { status, $push: { tracking: { status, timestamp: new Date(), note: 'Status updated' } } }, { new: true });
    res.json(order);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

module.exports = router;
