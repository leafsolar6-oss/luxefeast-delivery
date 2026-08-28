/**
 * Real-time choreography — every lifecycle transition alerts every affected party.
 *
 * Rooms:
 *   customer:{id}   — a customer's private channel
 *   shop:{id}       — a shop's dashboard channel
 *   rider:{id}      — a rider's private channel
 *   riders:online   — all riders currently available (dispatch offers)
 *   order:{id}      — everyone following one order (live tracking screen)
 *
 * Event matrix (server → clients):
 *   order:placed        → shop                        (new order alert)
 *   order:accepted      → customer, order             (+ prep ETA)
 *   order:rejected      → customer                    (+ refund notice)
 *   order:preparing     → customer, order
 *   order:ready         → customer, order, rider      (kitchen done)
 *   delivery:offer      → riders:online               (order available for pickup)
 *   delivery:taken      → riders:online               (offer no longer available)
 *   rider:assigned      → customer, shop, order       (rider name/phone/vehicle)
 *   rider:at_shop       → customer, shop, order
 *   order:picked_up     → customer, shop, order
 *   order:in_transit    → customer, order
 *   rider:location      → order                       (live GPS breadcrumb)
 *   order:arrived       → customer, order
 *   order:delivered     → customer, shop, rider, order (+ rider payout)
 *   order:cancelled     → shop, rider (if assigned), order
 */

const { query } = require('../config/db');
const { sendToUsers } = require('../services/push');

let io = null;

function init(ioInstance) {
  io = ioInstance;

  io.on('connection', (socket) => {
    // Every client registers itself: { role: 'customer'|'shop'|'rider', id }
    socket.on('register', ({ role, id }) => {
      if (!role || !id) return;
      socket.join(`${role}:${id}`);
      if (role === 'rider') socket.join('riders:online');
      socket.emit('registered', { role, id });
    });

    socket.on('join-order', (orderId) => socket.join(`order:${orderId}`));
    socket.on('leave-order', (orderId) => socket.leave(`order:${orderId}`));

    // Rider live GPS → everyone watching that order (customer tracking map).
    // Also persisted so the map has a position even after app restarts.
    socket.on('rider:location', ({ orderId, riderId, lat, lng }) => {
      if (!orderId) return;
      if (riderId && typeof lat === 'number' && typeof lng === 'number') {
        query(`UPDATE riders SET lat = $1, lng = $2 WHERE id = $3`, [lat, lng, riderId]).catch(() => {});
      }
      io.to(`order:${orderId}`).emit('rider:location', {
        orderId, riderId, lat, lng, timestamp: new Date().toISOString(),
      });
    });
  });
}

function emitTo(rooms, event, payload) {
  if (!io) return;
  const body = { ...payload, event, timestamp: new Date().toISOString() };
  [...new Set(rooms)].forEach((room) => io.to(room).emit(event, body));
}

/** Broadcast a lifecycle event to all parties affected by this order. */
function broadcastOrderEvent(event, order, extra = {}) {
  const rooms = { customer: `customer:${order.customer_id}`, shop: `shop:${order.shop_id}`, order: `order:${order.id}` };
  const riderRoom = order.rider_id ? `rider:${order.rider_id}` : null;
  const payload = { order, ...extra };

  // 1) Real-time sockets → in-app pop-ups for open apps.
  switch (event) {
    case 'order:placed':     emitTo([rooms.shop], event, payload); break;
    case 'order:accepted':   emitTo([rooms.customer, rooms.order], event, payload); break;
    case 'order:rejected':   emitTo([rooms.customer, rooms.order], event, payload); break;
    case 'order:preparing':  emitTo([rooms.customer, rooms.order], event, payload); break;
    case 'order:ready':      emitTo([rooms.customer, rooms.order, riderRoom].filter(Boolean), event, payload); break;
    case 'delivery:offer':   emitTo(['riders:online'], event, payload); break;
    case 'delivery:taken':   emitTo(['riders:online'], event, payload); break;
    case 'rider:assigned':   emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload); break;
    case 'rider:at_shop':    emitTo([rooms.customer, rooms.shop, rooms.order], event, payload); break;
    case 'order:picked_up':  emitTo([rooms.customer, rooms.shop, rooms.order], event, payload); break;
    case 'order:in_transit': emitTo([rooms.customer, rooms.order], event, payload); break;
    case 'order:arrived':    emitTo([rooms.customer, rooms.order], event, payload); break;
    case 'order:delivered':  emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload); break;
    case 'order:cancelled':  emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload); break;
    default:                 emitTo([rooms.order], event, payload); break;
  }

  // 2) Device pushes (FCM) → notifications for closed/killed apps.
  //    Fire-and-forget: never blocks the HTTP response.
  pushOrderEvent(event, order, extra).catch(() => {});
}

// --------------------------------------------------------- push pipeline ---

const PUSH_TITLES = {
  'order:placed': '🔔 New order',
  'order:accepted': 'Order accepted 🎉',
  'order:rejected': 'Order rejected',
  'order:preparing': 'Being prepared 👨\u200d🍳',
  'order:ready': 'Ready for pickup 📦',
  'rider:assigned': 'Rider assigned 🏍️',
  'order:picked_up': 'Rider picked up your order',
  'order:in_transit': 'On the way 🛵',
  'order:arrived': 'Rider has arrived 📍',
  'order:delivered': 'Delivered — enjoy! 🎉',
  'order:cancelled': 'Order cancelled',
  'delivery:offer': '🛵 New delivery offer',
};

async function shopOwnerUserIds(shopId) {
  const { rows } = await query(
    `SELECT id FROM users WHERE role = 'shop' AND entity_id = $1`, [shopId]);
  return rows.map((r) => r.id);
}

async function assignedRiderUserIds(riderId) {
  if (!riderId) return [];
  const { rows } = await query(
    `SELECT id FROM users WHERE role = 'rider' AND entity_id = $1`, [riderId]);
  return rows.map((r) => r.id);
}

async function availableRiderUserIds() {
  const { rows } = await query(
    `SELECT u.id FROM users u JOIN riders r ON r.id = u.entity_id
      WHERE u.role = 'rider' AND r.status = 'available'`);
  return rows.map((r) => r.id);
}

/** Who gets a device push for this event? (Never the actor who triggered it.) */
async function pushAudience(event, order) {
  const customer = [Number(order.customer_id)];
  switch (event) {
    case 'order:placed':
      return await shopOwnerUserIds(order.shop_id);
    case 'delivery:offer':
      return await availableRiderUserIds();
    case 'rider:assigned':
      return [...customer, ...(await shopOwnerUserIds(order.shop_id))];
    case 'order:ready':
      return [...customer, ...(await assignedRiderUserIds(order.rider_id))];
    case 'order:cancelled':
      // the customer triggered it — notify the shop (+ assigned rider) instead
      return [...(await shopOwnerUserIds(order.shop_id)), ...(await assignedRiderUserIds(order.rider_id))];
    case 'order:accepted':
    case 'order:rejected':
    case 'order:preparing':
    case 'order:picked_up':
    case 'order:in_transit':
    case 'order:arrived':
    case 'order:delivered':
      return customer;
    default:
      return [];
  }
}

async function pushOrderEvent(event, order, extra) {
  const users = await pushAudience(event, order);
  if (!users.length) return;
  await sendToUsers(
    users,
    PUSH_TITLES[event] || 'Nature Fete',
    extra.message || '',
    { orderId: order.id, event }
  );
}

module.exports = { init, broadcastOrderEvent, emitTo };
