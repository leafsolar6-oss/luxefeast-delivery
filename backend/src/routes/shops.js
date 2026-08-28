const express = require('express');
const router = express.Router();
const { query } = require('../config/db');

router.get('/', async (_req, res) => {
  try {
    const { rows } = await query(`SELECT * FROM shops WHERE is_open = TRUE ORDER BY rating DESC`);
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.get('/:id', async (req, res) => {
  try {
    const { rows } = await query(`SELECT * FROM shops WHERE id = $1`, [req.params.id]);
    if (!rows[0]) return res.status(404).json({ message: 'Shop not found' });
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
