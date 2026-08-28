const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const { sendEmailCode, sendSmsCode, generateCode } = require('../services/notify');

const JWT_SECRET = process.env.JWT_SECRET || 'luxefeast-dev-secret';
const sign = (u) =>
  jwt.sign({ id: u.id, role: u.role, entityId: u.entity_id }, JWT_SECRET, { expiresIn: '30d' });

const publicUser = (u) => ({
  id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role,
  emailVerified: u.email_verified, phoneVerified: u.phone_verified,
  entityId: u.entity_id,
});

async function issueCode(userId, channel, destination) {
  const code = generateCode();
  await query(`UPDATE verification_codes SET consumed = TRUE WHERE user_id = $1 AND channel = $2`, [userId, channel]);
  await query(
    `INSERT INTO verification_codes (user_id, channel, code, expires_at)
     VALUES ($1,$2,$3, now() + interval '10 minutes')`,
    [userId, channel, code]
  );
  const result = channel === 'email' ? await sendEmailCode(destination, code) : await sendSmsCode(destination, code);
  // Dev mode (no provider key configured): expose the code so the flow is testable.
  return result.dev ? code : null;
}

/**
 * POST /api/auth/register
 * { name, email, phone, password, role: customer|shop|rider, address?, shopName?, vehicleType? }
 * Creates the account (+ linked shop/rider record) and sends email + SMS OTPs.
 */
router.post('/register', async (req, res) => {
  try {
    const { name, email, phone, password, role = 'customer', address, shopName, vehicleType } = req.body;
    if (!name || !email || !phone || !password) {
      return res.status(400).json({ message: 'name, email, phone and password are required' });
    }
    if (!/^\+?\d{10,15}$/.test(phone.replace(/\s/g, ''))) {
      return res.status(400).json({ message: 'Enter a valid phone number (e.g. +2348012345678)' });
    }
    if (password.length < 6) return res.status(400).json({ message: 'Password must be at least 6 characters' });

    const existing = await query(`SELECT id FROM users WHERE email = $1`, [email.toLowerCase()]);
    if (existing.rows[0]) return res.status(400).json({ message: 'An account with this email already exists' });

    // Create the linked business entity for shop/rider roles.
    let entityId = null;
    if (role === 'shop') {
      const r = await query(
        `INSERT INTO shops (name, email, phone, address, city) VALUES ($1,$2,$3,$4,'Lagos')
         ON CONFLICT (email) DO UPDATE SET phone = EXCLUDED.phone RETURNING id`,
        [shopName || `${name}'s Kitchen`, email.toLowerCase(), phone, address || 'Lagos, Nigeria']
      );
      entityId = r.rows[0].id;
    } else if (role === 'rider') {
      const r = await query(
        `INSERT INTO riders (name, email, phone, vehicle_type, status) VALUES ($1,$2,$3,$4,'offline')
         ON CONFLICT (email) DO UPDATE SET phone = EXCLUDED.phone RETURNING id`,
        [name, email.toLowerCase(), phone, vehicleType || 'Motorcycle']
      );
      entityId = r.rows[0].id;
    }

    const hash = await bcrypt.hash(password, 10);
    const { rows } = await query(
      `INSERT INTO users (name, email, phone, password_hash, role, address, entity_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [name, email.toLowerCase(), phone, hash, role, address, entityId]
    );
    const user = rows[0];

    const devEmailCode = await issueCode(user.id, 'email', user.email);
    const devPhoneCode = await issueCode(user.id, 'phone', user.phone);

    res.status(201).json({
      message: 'Account created — verify your email and phone number',
      userId: user.id,
      user: publicUser(user),
      // Present ONLY in dev mode (no RESEND_API_KEY / TERMII_API_KEY configured):
      ...(devEmailCode ? { devEmailCode } : {}),
      ...(devPhoneCode ? { devPhoneCode } : {}),
    });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

/** POST /api/auth/verify  { userId, channel: 'email'|'phone', code } */
router.post('/verify', async (req, res) => {
  try {
    const { userId, channel, code } = req.body;
    if (!userId || !channel || !code) return res.status(400).json({ message: 'userId, channel, code required' });

    const { rows } = await query(
      `UPDATE verification_codes SET consumed = TRUE
        WHERE user_id = $1 AND channel = $2 AND code = $3
          AND consumed = FALSE AND expires_at > now()
        RETURNING id`,
      [userId, channel, String(code).trim()]
    );
    if (!rows[0]) return res.status(400).json({ message: 'Invalid or expired code' });

    const col = channel === 'email' ? 'email_verified' : 'phone_verified';
    const u = await query(`UPDATE users SET ${col} = TRUE WHERE id = $1 RETURNING *`, [userId]);
    const user = u.rows[0];

    const fullyVerified = user.email_verified && user.phone_verified;
    res.json({
      message: `${channel === 'email' ? 'Email' : 'Phone number'} verified ✓`,
      user: publicUser(user),
      fullyVerified,
      ...(fullyVerified ? { token: sign(user) } : {}),
    });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

/** POST /api/auth/resend  { userId, channel } */
router.post('/resend', async (req, res) => {
  try {
    const { userId, channel } = req.body;
    const { rows } = await query(`SELECT * FROM users WHERE id = $1`, [userId]);
    const user = rows[0];
    if (!user) return res.status(404).json({ message: 'User not found' });
    const dest = channel === 'email' ? user.email : user.phone;
    const devCode = await issueCode(user.id, channel, dest);
    res.json({ message: `Code re-sent to your ${channel}`, ...(devCode ? { devCode } : {}) });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

/** POST /api/auth/login  { identifier (email or phone), password } */
router.post('/login', async (req, res) => {
  try {
    const { identifier, email, password } = req.body;
    const id = (identifier || email || '').trim();
    if (!id || !password) return res.status(400).json({ message: 'email/phone and password required' });

    const { rows } = await query(
      `SELECT * FROM users WHERE lower(email) = lower($1) OR replace(phone,' ','') = replace($1,' ','')`,
      [id]
    );
    const user = rows[0];
    if (!user || !user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    if (!user.email_verified && !user.phone_verified) {
      const devEmailCode = await issueCode(user.id, 'email', user.email);
      const devPhoneCode = await issueCode(user.id, 'phone', user.phone);
      return res.status(403).json({
        message: 'Account not verified — new codes sent',
        needsVerification: true,
        userId: user.id,
        user: publicUser(user),
        ...(devEmailCode ? { devEmailCode } : {}),
        ...(devPhoneCode ? { devPhoneCode } : {}),
      });
    }
    res.json({ token: sign(user), user: publicUser(user) });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

/** GET /api/auth/me — validate a stored token */
router.get('/me', async (req, res) => {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const payload = jwt.verify(token, JWT_SECRET);
    const { rows } = await query(`SELECT * FROM users WHERE id = $1`, [payload.id]);
    if (!rows[0]) return res.status(404).json({ message: 'User not found' });
    res.json({ user: publicUser(rows[0]) });
  } catch (e) { res.status(401).json({ message: 'Invalid or expired token' }); }
});

// --------------------------------------------------- device push tokens ---

function authUser(req) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  return jwt.verify(token, JWT_SECRET); // throws on invalid
}

/** POST /api/auth/device-token  { token, platform } — register for pushes */
router.post('/device-token', async (req, res) => {
  try {
    const payload = authUser(req);
    const { token, platform = 'android' } = req.body;
    if (!token) return res.status(400).json({ message: 'token is required' });
    await query(
      `INSERT INTO device_tokens (user_id, token, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, last_seen_at = now()`,
      [payload.id, token, platform]
    );
    res.status(201).json({ message: 'Device registered for push notifications' });
  } catch (e) {
    const code = e.name === 'JsonWebTokenError' ? 401 : 500;
    res.status(code).json({ message: code === 401 ? 'Invalid or expired token' : e.message });
  }
});

/** DELETE /api/auth/device-token  { token } — stop pushes (logout) */
router.delete('/device-token', async (req, res) => {
  try {
    const payload = authUser(req);
    const { token } = req.body;
    if (!token) return res.status(400).json({ message: 'token is required' });
    await query(`DELETE FROM device_tokens WHERE token = $1 AND user_id = $2`, [token, payload.id]);
    res.json({ message: 'Device unregistered' });
  } catch (e) {
    const code = e.name === 'JsonWebTokenError' ? 401 : 500;
    res.status(code).json({ message: code === 401 ? 'Invalid or expired token' : e.message });
  }
});

module.exports = router;
