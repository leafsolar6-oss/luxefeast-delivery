const express = require('express');
const router = express.Router();
const { query } = require('../config/db');

router.get('/', async (_req, res) => {
  try {
    const { rows } = await query(`SELECT id, name, phone, vehicle_type, status, rating, lat, lng FROM riders ORDER BY name`);
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.get('/:id/earnings', async (req, res) => {
  try {
    const { rows: rider } = await query(`SELECT id, name, total_earnings FROM riders WHERE id = $1`, [req.params.id]);
    if (!rider[0]) return res.status(404).json({ message: 'Rider not found' });
    const { rows: payments } = await query(
      `SELECT p.amount, p.status, p.created_at, o.code AS order_code
         FROM rider_payments p JOIN orders o ON o.id = p.order_id
        WHERE p.rider_id = $1 ORDER BY p.created_at DESC LIMIT 50`,
      [req.params.id]
    );
    res.json({ ...rider[0], payments });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.put('/:id/status', async (req, res) => {
  try {
    const { status } = req.body; // available | on_delivery | offline
    const { rows } = await query(
      `UPDATE riders SET status = $1 WHERE id = $2 RETURNING id, name, status`,
      [status, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ message: 'Rider not found' });
    res.json(rows[0]);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

router.put('/:id/location', async (req, res) => {
  try {
    const { lat, lng } = req.body;
    const { rows } = await query(
      `UPDATE riders SET lat = $1, lng = $2 WHERE id = $3 RETURNING id, lat, lng`,
      [lat, lng, req.params.id]
    );
    res.json(rows[0]);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

module.exports = router;
