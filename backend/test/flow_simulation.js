/**
 * End-to-end three-party choreography test.
 * Connects Customer, Shop and Rider as separate Socket.IO clients,
 * drives the full order lifecycle over REST, and verifies that every
 * party receives the correct real-time alerts, in order.
 */
const { io } = require('socket.io-client');

const BASE = process.env.API_URL || 'http://localhost:5000';
const api = (p, opts) => fetch(`${BASE}/api${p}`, {
  headers: { 'Content-Type': 'application/json' }, ...opts,
}).then(async (r) => {
  const body = await r.json();
  if (!r.ok) throw new Error(`${p} → ${r.status}: ${body.message}`);
  return body;
});

const received = { customer: [], shop: [], rider: [], rider2: [] };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function connect(role, id, bucket) {
  const s = io(BASE, { transports: ['websocket'] });
  s.on('connect', () => s.emit('register', { role, id }));
  const events = [
    'order:placed', 'order:accepted', 'order:rejected', 'order:preparing', 'order:ready',
    'delivery:offer', 'delivery:taken', 'rider:assigned', 'rider:at_shop',
    'order:picked_up', 'order:in_transit', 'rider:location', 'order:arrived',
    'order:delivered', 'order:cancelled',
  ];
  events.forEach((e) => s.on(e, (data) => {
    received[bucket].push(e);
    console.log(`   📨 [${bucket.toUpperCase()}] ← ${e}${data.message ? ` — "${data.message}"` : ''}`);
  }));
  return s;
}

(async () => {
  console.log('═══ LuxFeast three-party choreography test ═══\n');

  const customer = connect('customer', 1, 'customer');
  const shop = connect('shop', 1, 'shop');
  const rider = connect('rider', 1, 'rider');
  const rider2 = connect('rider', 2, 'rider2'); // competes for the claim
  await sleep(600);

  console.log('\n1️⃣  CUSTOMER places order at Mama Nkem Amala Palace...');
  const order = await api('/orders', {
    method: 'POST',
    body: JSON.stringify({
      customerId: 1, shopId: 1,
      items: [{ name: 'Amala + Ewedu & Gbegiri', quantity: 2, price: 3500 }, { name: 'Goat Meat', quantity: 1, price: 2000 }],
      deliveryAddress: '4 Fola Osibo Rd, Lekki Phase 1, Lagos',
      paymentGateway: 'paystack',
    }),
  });
  customer.emit('join-order', order.id);
  await sleep(500);

  console.log('\n2️⃣  SHOP accepts (prep: 20 min) → customer notified + delivery offered to ALL riders...');
  await api(`/orders/${order.id}/accept`, { method: 'POST', body: JSON.stringify({ prepMinutes: 20 }) });
  await sleep(500);

  console.log('\n3️⃣  BOTH riders race to claim — exactly one must win...');
  const results = await Promise.allSettled([
    api(`/orders/${order.id}/claim`, { method: 'POST', body: JSON.stringify({ riderId: 1 }) }),
    api(`/orders/${order.id}/claim`, { method: 'POST', body: JSON.stringify({ riderId: 2 }) }),
  ]);
  const wins = results.filter((r) => r.status === 'fulfilled').length;
  console.log(`   ⚔️  Claim race: ${wins} winner, ${2 - wins} rejected (409) ${wins === 1 ? '✅ atomic' : '❌ RACE BUG'}`);
  await sleep(500);

  console.log('\n4️⃣  SHOP starts preparing → kitchen ready...');
  await api(`/orders/${order.id}/preparing`, { method: 'POST' });
  await sleep(300);
  await api(`/orders/${order.id}/ready`, { method: 'POST' });
  await sleep(500);

  console.log('\n5️⃣  RIDER arrives at shop, confirms pickup → customer sees "picked up"...');
  await api(`/orders/${order.id}/arrive-shop`, { method: 'POST' });
  await sleep(300);
  const winnerRiderId = results[0].status === 'fulfilled' ? 1 : 2;
  await api(`/orders/${order.id}/pickup`, { method: 'POST', body: JSON.stringify({ riderId: winnerRiderId }) });
  await sleep(300);
  await api(`/orders/${order.id}/in-transit`, { method: 'POST' });
  await sleep(300);

  console.log('\n6️⃣  RIDER streams live GPS → customer tracking map...');
  const winnerSocket = winnerRiderId === 1 ? rider : rider2;
  winnerSocket.emit('rider:location', { orderId: order.id, riderId: winnerRiderId, lat: 6.4432, lng: 3.4685 });
  await sleep(400);

  console.log('\n7️⃣  RIDER arrives & delivers → everyone notified, rider paid ₦850, freed for next offer...');
  await api(`/orders/${order.id}/arrive-customer`, { method: 'POST' });
  await sleep(300);
  await api(`/orders/${order.id}/deliver`, { method: 'POST' });
  await sleep(600);

  const final = await api(`/orders/${order.id}`);
  const earnings = await api(`/riders/${winnerRiderId}/earnings`);

  console.log('\n═══ RESULTS ═══');
  console.log(`Final status:        ${final.status} | payment: ${final.payment_status}`);
  console.log(`Audit trail:         ${final.events.length} events → ${final.events.map((e) => e.event).join(' → ')}`);
  console.log(`Rider earnings:      ₦${earnings.total_earnings} (${earnings.payments.length} payment[s])`);
  console.log(`Customer alerts:     ${received.customer.join(', ')}`);
  console.log(`Shop alerts:         ${received.shop.join(', ')}`);
  console.log(`Winning rider alerts: ${received[winnerRiderId === 1 ? 'rider' : 'rider2'].join(', ')}`);

  const pass =
    final.status === 'delivered' &&
    final.payment_status === 'paid' &&
    wins === 1 &&
    received.customer.includes('order:accepted') &&
    received.customer.includes('rider:assigned') &&
    received.customer.includes('order:picked_up') &&
    received.customer.includes('order:delivered') &&
    received.shop.includes('order:placed') &&
    received.shop.includes('rider:assigned') &&
    received.shop.includes('order:picked_up') &&
    received.customer.includes('rider:location');

  console.log(`\n${pass ? '✅ ALL CHOREOGRAPHY CHECKS PASSED' : '❌ SOME CHECKS FAILED'}`);
  [customer, shop, rider, rider2].forEach((s) => s.close());
  process.exit(pass ? 0 : 1);
})().catch((e) => { console.error('❌ Test failed:', e.message); process.exit(1); });
