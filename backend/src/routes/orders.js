const express = require('express');
const router = express.Router();
const { query, pool } = require('../config/db');
const { getTransition, CLAIMABLE_STATUSES, CUSTOMER_STEPS, computeEta } = require('../domain/stateMachine');
const { broadcastOrderEvent } = require('../realtime/events');

async function logEvent(orderId, actor, event, fromStatus, toStatus, note) {
  await query(
    `INSERT INTO order_events (order_id, actor, event, from_status, to_status, note)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [orderId, actor, event, fromStatus, toStatus, note || null]
  );
}

async function loadOrder(id) {
  const { rows } = await query(
    `SELECT o.*,
            s.name AS shop_name, s.address AS shop_address, s.phone AS shop_phone,
            s.lat AS shop_lat, s.lng AS shop_lng,
            u.name AS customer_name, u.phone AS customer_phone,
            r.name AS rider_name, r.phone AS rider_phone, r.vehicle_type AS rider_vehicle, r.rating AS rider_rating,
            r.lat AS rider_lat, r.lng AS rider_lng
       FROM orders o
       JOIN shops s ON s.id = o.shop_id
       JOIN users u ON u.id = o.customer_id
  LEFT JOIN riders r ON r.id = o.rider_id
      WHERE o.id = $1`,
    [id]
  );
  return rows[0] || null;
}

/**
 * Atomic guarded transition (optimistic concurrency):
 * only succeeds if the order is still in an allowed `from` status.
 */
async function applyTransition(id, transitionName, { note, extraSet = '', extraParams = [] } = {}) {
  const t = getTransition(transitionName);
  if (!t) return { error: { code: 400, message: `Unknown transition '${transitionName}'` } };

  const timestampCol = {
    accept: 'accepted_at', ready: 'ready_at', pickup: 'picked_up_at',
    deliver: 'delivered_at', cancel: 'cancelled_at', reject: 'cancelled_at',
  }[transitionName];

  const params = [t.to, id, t.from, ...extraParams];
  const { rows } = await query(
    `UPDATE orders
        SET status = $1,
            version = version + 1,
            updated_at = now()
            ${timestampCol ? `, ${timestampCol} = now()` : ''}
            ${extraSet}
      WHERE id = $2 AND status = ANY($3)
      RETURNING *`,
    params
  );

  if (!rows[0]) {
    const current = await loadOrder(id);
    if (!current) return { error: { code: 404, message: 'Order not found' } };
    return {
      error: {
        code: 409,
        message: `Cannot '${transitionName}' — order is '${current.status}' (requires: ${t.from.join(', ')}). Someone may have updated it first.`,
      },
    };
  }

  const order = await loadOrder(id);
  await logEvent(id, t.actor, transitionName, rows[0].status === t.to ? t.from.join('|') : null, t.to, note);
  return { order };
}

// ---------------------------------------------------------------- queries ---

// Reject non-numeric :id up front (e.g. "/api/orders/null") instead of
// throwing a Postgres bigint parse error deep in a query.
router.param('id', (req, res, next, id) => {
  if (!/^\d+$/.test(id)) return res.status(400).json({ message: 'Invalid order id' });
  next();
});

router.get('/', async (req, res) => {
  try {
    const { customerId, shopId, riderId, status, open } = req.query;
    const where = [];
    const params = [];
    if (customerId) { params.push(customerId); where.push(`o.customer_id = $${params.length}`); }
    if (shopId)     { params.push(shopId);     where.push(`o.shop_id = $${params.length}`); }
    if (riderId)    { params.push(riderId);    where.push(`o.rider_id = $${params.length}`); }
    if (status)     { params.push(status);     where.push(`o.status = $${params.length}`); }
    if (open === 'true') where.push(`o.status NOT IN ('delivered','cancelled','rejected')`);

    const { rows } = await query(
      `SELECT o.*, s.name AS shop_name, s.address AS shop_address,
              r.name AS rider_name, u.name AS customer_name
         FROM orders o
         JOIN shops s ON s.id = o.shop_id
         JOIN users u ON u.id = o.customer_id
    LEFT JOIN riders r ON r.id = o.rider_id
        ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
        ORDER BY o.placed_at DESC LIMIT 100`,
      params
    );
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Unclaimed deliveries a rider can pick from (dispatch feed).
router.get('/available-deliveries', async (_req, res) => {
  try {
    const { rows } = await query(
      `SELECT o.id, o.code, o.delivery_fee, o.delivery_address, o.status,
              s.name AS shop_name, s.address AS shop_address
         FROM orders o JOIN shops s ON s.id = o.shop_id
        WHERE o.rider_id IS NULL AND o.status = ANY($1)
        ORDER BY o.placed_at ASC`,
      [CLAIMABLE_STATUSES]
    );
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.get('/:id', async (req, res) => {
  try {
    const order = await loadOrder(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    const { rows: events } = await query(
      `SELECT actor, event, from_status, to_status, note, created_at
         FROM order_events WHERE order_id = $1 ORDER BY created_at`,
      [req.params.id]
    );
    res.json({ ...order, events, steps: CUSTOMER_STEPS });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// ------------------------------------------------------- customer actions ---

// Place order → alerts the shop instantly.
router.post('/', async (req, res) => {
  try {
    const { customerId, shopId, items, deliveryAddress, paymentGateway = 'paystack', dropoffLat, dropoffLng } = req.body;
    if (!customerId || !shopId || !Array.isArray(items) || items.length === 0 || !deliveryAddress) {
      return res.status(400).json({ message: 'customerId, shopId, items[], deliveryAddress are required' });
    }
    const subtotal = items.reduce((sum, i) => sum + Number(i.price) * Number(i.quantity || 1), 0);
    const deliveryFee = 850, serviceFee = 200;
    const total = subtotal + deliveryFee + serviceFee;
    const code = 'LF-' + Date.now().toString().slice(-6);

    const { rows } = await query(
      `INSERT INTO orders (code, customer_id, shop_id, items, subtotal, delivery_fee, service_fee, total, payment_gateway, delivery_address, dropoff_lat, dropoff_lng)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
      [code, customerId, shopId, JSON.stringify(items), subtotal, deliveryFee, serviceFee, total, paymentGateway, deliveryAddress,
       dropoffLat ?? 6.4531, dropoffLng ?? 3.4470] // default: Lekki Phase 1
    );
    const order = await loadOrder(rows[0].id);
    await logEvent(order.id, 'customer', 'place', null, 'placed', `Order ${code} placed — payment authorized via ${paymentGateway}`);

    broadcastOrderEvent('order:placed', order, { message: `New order ${code} from ${order.customer_name}` });
    res.status(201).json(order);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

router.post('/:id/cancel', async (req, res) => {
  const result = await applyTransition(req.params.id, 'cancel', {
    note: req.body.reason || 'Cancelled by customer',
    extraSet: `, cancel_reason = $4, payment_status = 'refunded'`,
    extraParams: [req.body.reason || 'Cancelled by customer'],
  });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:cancelled', result.order, { message: `Order ${result.order.code} was cancelled — refund initiated` });
  res.json(result.order);
});

// ----------------------------------------------------------- shop actions ---

// Shop accepts (with prep estimate) → customer notified + dispatch offer to riders.
router.post('/:id/accept', async (req, res) => {
  const prepMinutes = Number(req.body.prepMinutes) || 20;
  const eta = computeEta(prepMinutes);
  const result = await applyTransition(req.params.id, 'accept', {
    note: `Shop accepted — est. prep ${prepMinutes} min`,
    extraSet: `, prep_minutes = $4, eta = $5`,
    extraParams: [prepMinutes, eta],
  });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });

  broadcastOrderEvent('order:accepted', result.order, {
    message: `${result.order.shop_name} confirmed your order — ready around ${eta.toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' })}`,
  });
  // Parallel dispatch: offer the delivery to all available riders immediately.
  broadcastOrderEvent('delivery:offer', result.order, {
    message: `Pickup at ${result.order.shop_name} — earn ₦${result.order.delivery_fee}`,
  });
  res.json(result.order);
});

router.post('/:id/reject', async (req, res) => {
  const result = await applyTransition(req.params.id, 'reject', {
    note: req.body.reason || 'Shop cannot fulfil this order',
    extraSet: `, cancel_reason = $4, payment_status = 'refunded'`,
    extraParams: [req.body.reason || 'Shop cannot fulfil this order'],
  });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:rejected', result.order, { message: 'The restaurant could not take your order — full refund initiated' });
  res.json(result.order);
});

router.post('/:id/preparing', async (req, res) => {
  const result = await applyTransition(req.params.id, 'start_preparing', { note: 'Kitchen started preparing' });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:preparing', result.order, { message: 'Your food is being prepared' });
  res.json(result.order);
});

router.post('/:id/ready', async (req, res) => {
  const result = await applyTransition(req.params.id, 'ready', { note: 'Order ready for pickup' });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:ready', result.order, { message: `Order ${result.order.code} is packed and ready for pickup` });
  if (!result.order.rider_id) {
    broadcastOrderEvent('delivery:offer', result.order, { message: `URGENT: food ready at ${result.order.shop_name} — earn ₦${result.order.delivery_fee}` });
  }
  res.json(result.order);
});

// ---------------------------------------------------------- rider actions ---

// Rider claims a delivery — atomic: exactly ONE rider can win the race.
router.post('/:id/claim', async (req, res) => {
  try {
    const riderId = Number(req.body.riderId);
    if (!riderId) return res.status(400).json({ message: 'riderId is required' });

    const { rows } = await query(
      `UPDATE orders
          SET rider_id = $1, rider_assigned_at = now(), version = version + 1, updated_at = now()
        WHERE id = $2 AND rider_id IS NULL AND status = ANY($3)
        RETURNING id`,
      [riderId, req.params.id, CLAIMABLE_STATUSES]
    );
    if (!rows[0]) return res.status(409).json({ message: 'Delivery already taken or not claimable' });

    await query(`UPDATE riders SET status = 'on_delivery' WHERE id = $1`, [riderId]);
    const order = await loadOrder(req.params.id);
    await logEvent(order.id, 'rider', 'claim', order.status, order.status, `${order.rider_name} accepted the delivery`);

    broadcastOrderEvent('rider:assigned', order, {
      message: `${order.rider_name} (${order.rider_vehicle}) will deliver order ${order.code}`,
      rider: { id: order.rider_id, name: order.rider_name, phone: order.rider_phone, vehicle: order.rider_vehicle, rating: order.rider_rating },
    });
    broadcastOrderEvent('delivery:taken', order, { orderId: order.id });
    res.json(order);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/:id/arrive-shop', async (req, res) => {
  try {
    const { rows } = await query(
      `UPDATE orders SET rider_at_shop_at = now(), version = version + 1, updated_at = now()
        WHERE id = $1 AND rider_id IS NOT NULL AND status = ANY($2) RETURNING id`,
      [req.params.id, CLAIMABLE_STATUSES]
    );
    if (!rows[0]) return res.status(409).json({ message: 'Order not in a pickup-pending state or no rider assigned' });
    const order = await loadOrder(req.params.id);
    await logEvent(order.id, 'rider', 'arrive_shop', order.status, order.status, `${order.rider_name} arrived at ${order.shop_name}`);
    broadcastOrderEvent('rider:at_shop', order, { message: `${order.rider_name} is at the restaurant` });
    res.json(order);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Rider confirms pickup → customer sees "picked up" instantly.
router.post('/:id/pickup', async (req, res) => {
  const current = await loadOrder(req.params.id);
  if (current && Number(req.body.riderId) && Number(current.rider_id) !== Number(req.body.riderId)) {
    return res.status(403).json({ message: 'Only the assigned rider can confirm pickup' });
  }
  const result = await applyTransition(req.params.id, 'pickup', { note: 'Rider confirmed pickup at shop' });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:picked_up', result.order, { message: `${result.order.rider_name} picked up order ${result.order.code}` });
  res.json(result.order);
});

router.post('/:id/in-transit', async (req, res) => {
  const result = await applyTransition(req.params.id, 'start_transit', { note: 'Rider en route to customer' });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:in_transit', result.order, { message: 'Your order is on the way' });
  res.json(result.order);
});

router.post('/:id/arrive-customer', async (req, res) => {
  const result = await applyTransition(req.params.id, 'arrive', { note: 'Rider arrived at delivery address' });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });
  broadcastOrderEvent('order:arrived', result.order, { message: `${result.order.rider_name} has arrived with your order` });
  res.json(result.order);
});

// Delivered → settle: mark paid, pay rider, free the rider for new offers.
router.post('/:id/deliver', async (req, res) => {
  const result = await applyTransition(req.params.id, 'deliver', {
    note: 'Delivery confirmed',
    extraSet: `, payment_status = 'paid'`,
  });
  if (result.error) return res.status(result.error.code).json({ message: result.error.message });

  const order = result.order;
  if (order.rider_id) {
    await query(`INSERT INTO rider_payments (rider_id, order_id, amount) VALUES ($1,$2,$3)`,
      [order.rider_id, order.id, order.delivery_fee]);
    await query(`UPDATE riders SET status = 'available', total_earnings = total_earnings + $1 WHERE id = $2`,
      [order.delivery_fee, order.rider_id]);
  }
  broadcastOrderEvent('order:delivered', order, {
    message: `Order ${order.code} delivered — ₦${order.delivery_fee} paid to ${order.rider_name}`,
    riderPayout: Number(order.delivery_fee),
  });
  res.json(order);
});

module.exports = router;
