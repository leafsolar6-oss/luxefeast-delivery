const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');

const JWT_SECRET = process.env.JWT_SECRET || 'luxefeast-dev-secret';

router.post('/register', async (req, res) => {
  try {
    const { name, email, password, phone, role = 'customer', address } = req.body;
    if (!name || !email || !password) return res.status(400).json({ message: 'name, email, password required' });
    const existing = await query(`SELECT id FROM users WHERE email = $1`, [email]);
    if (existing.rows[0]) return res.status(400).json({ message: 'User exists' });

    const hash = await bcrypt.hash(password, 10);
    const { rows } = await query(
      `INSERT INTO users (name, email, password_hash, phone, role, address)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, name, email, role`,
      [name, email, hash, phone, role, address]
    );
    const token = jwt.sign({ id: rows[0].id, role: rows[0].role }, JWT_SECRET, { expiresIn: '30d' });
    res.status(201).json({ token, user: rows[0] });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const { rows } = await query(`SELECT * FROM users WHERE email = $1`, [email]);
    const user = rows[0];
    if (!user || !user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
