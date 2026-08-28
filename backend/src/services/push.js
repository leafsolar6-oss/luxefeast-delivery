/**
 * Firebase Cloud Messaging — real device push notifications.
 *
 * Setup (Render dashboard → Environment):
 *   FIREBASE_SERVICE_ACCOUNT = <contents of the service-account JSON file>
 * Missing/invalid → pushes are skipped silently (sockets still work).
 */
const admin = require('firebase-admin');
const { query } = require('../config/db');

let messaging = null;
let warned = false;

function init() {
  if (messaging) return true;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) {
    if (!warned) { console.log('Push: FIREBASE_SERVICE_ACCOUNT not set — device notifications disabled'); warned = true; }
    return false;
  }
  try {
    const creds = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (admin.apps.length === 0) {
      admin.initializeApp({ credential: admin.credential.cert(creds) });
    }
    messaging = admin.messaging();
    console.log('Push: Firebase Admin ready');
    return true;
  } catch (e) {
    if (!warned) { console.error('Push: invalid FIREBASE_SERVICE_ACCOUNT —', e.message); warned = true; }
    return false;
  }
}

async function tokensFor(userIds) {
  if (!userIds.length) return [];
  const { rows } = await query(
    `SELECT token FROM device_tokens WHERE user_id = ANY($1)`,
    [userIds]
  );
  return rows.map((r) => r.token);
}

/**
 * Send a push to every registered device of the given users.
 * `data` rides along for tap-routing (orderId, event…).
 */
async function sendToUsers(userIds, title, body, data = {}) {
  try {
    if (!init()) return;
    const tokens = await tokensFor(userIds);
    if (!tokens.length) return;

    const message = {
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: {
        priority: 'high',
        notification: { channelId: 'orders', priority: 'high' },
      },
      tokens,
    };

    const response = await messaging.sendEachForMulticast(message);

    // Prune dead tokens so the list stays healthy.
    const dead = response.responses
      .map((r, i) => (r.success ? null : tokens[i]))
      .filter(Boolean);
    if (dead.length) {
      await query(`DELETE FROM device_tokens WHERE token = ANY($1)`, [dead]).catch(() => {});
    }
  } catch (e) {
    console.error('Push send failed:', e.message);
  }
}

function ready() {
  init();
  return messaging !== null;
}

module.exports = { sendToUsers, ready };
