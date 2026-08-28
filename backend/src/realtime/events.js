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
    socket.on('rider:location', ({ orderId, riderId, lat, lng }) => {
      if (!orderId) return;
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

  switch (event) {
    case 'order:placed':     return emitTo([rooms.shop], event, payload);
    case 'order:accepted':   return emitTo([rooms.customer, rooms.order], event, payload);
    case 'order:rejected':   return emitTo([rooms.customer, rooms.order], event, payload);
    case 'order:preparing':  return emitTo([rooms.customer, rooms.order], event, payload);
    case 'order:ready':      return emitTo([rooms.customer, rooms.order, riderRoom].filter(Boolean), event, payload);
    case 'delivery:offer':   return emitTo(['riders:online'], event, payload);
    case 'delivery:taken':   return emitTo(['riders:online'], event, payload);
    case 'rider:assigned':   return emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload);
    case 'rider:at_shop':    return emitTo([rooms.customer, rooms.shop, rooms.order], event, payload);
    case 'order:picked_up':  return emitTo([rooms.customer, rooms.shop, rooms.order], event, payload);
    case 'order:in_transit': return emitTo([rooms.customer, rooms.order], event, payload);
    case 'order:arrived':    return emitTo([rooms.customer, rooms.order], event, payload);
    case 'order:delivered':  return emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload);
    case 'order:cancelled':  return emitTo([rooms.customer, rooms.shop, rooms.order, riderRoom].filter(Boolean), event, payload);
    default:                 return emitTo([rooms.order], event, payload);
  }
}

module.exports = { init, broadcastOrderEvent, emitTo };
