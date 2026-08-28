/**
 * LuxFeast Order State Machine — international-standard food delivery lifecycle.
 *
 * Modeled on the Uber Eats / DoorDash order journey:
 *   PLACED → ACCEPTED → PREPARING → READY_FOR_PICKUP → PICKED_UP → IN_TRANSIT → ARRIVED → DELIVERED
 * Branches: PLACED → REJECTED (shop), PLACED/ACCEPTED → CANCELLED (customer).
 *
 * Rider dispatch runs IN PARALLEL with the kitchen (real-world dispatch pattern):
 * riders may claim an order any time from ACCEPTED onward; pickup requires
 * READY_FOR_PICKUP + an assigned rider.
 *
 * Every transition declares which party may perform it (actor guard) and is
 * applied atomically with `WHERE status = expected` (optimistic concurrency),
 * so duplicate/racing updates are rejected with 409.
 */

const STATUSES = [
  'placed', 'accepted', 'rejected', 'preparing', 'ready_for_pickup',
  'picked_up', 'in_transit', 'arrived', 'delivered', 'cancelled',
];

// transition name -> { from: [allowed current statuses], to, actor }
const TRANSITIONS = {
  accept:          { from: ['placed'],                       to: 'accepted',         actor: 'shop' },
  reject:          { from: ['placed'],                       to: 'rejected',         actor: 'shop' },
  start_preparing: { from: ['accepted'],                     to: 'preparing',        actor: 'shop' },
  ready:           { from: ['preparing'],                    to: 'ready_for_pickup', actor: 'shop' },
  pickup:          { from: ['ready_for_pickup'],             to: 'picked_up',        actor: 'rider' },
  start_transit:   { from: ['picked_up'],                    to: 'in_transit',       actor: 'rider' },
  arrive:          { from: ['in_transit'],                   to: 'arrived',          actor: 'rider' },
  deliver:         { from: ['arrived', 'in_transit'],        to: 'delivered',        actor: 'rider' },
  cancel:          { from: ['placed', 'accepted'],           to: 'cancelled',        actor: 'customer' },
};

// Rider may claim an order while the kitchen works (parallel dispatch).
const CLAIMABLE_STATUSES = ['accepted', 'preparing', 'ready_for_pickup'];

// Human-readable progress for customer tracking UI (happy path).
const CUSTOMER_STEPS = [
  { status: 'placed',           label: 'Order placed' },
  { status: 'accepted',         label: 'Restaurant confirmed your order' },
  { status: 'preparing',        label: 'Your food is being prepared' },
  { status: 'ready_for_pickup', label: 'Ready — waiting for rider pickup' },
  { status: 'picked_up',        label: 'Rider picked up your order' },
  { status: 'in_transit',       label: 'Rider is on the way' },
  { status: 'arrived',          label: 'Rider has arrived' },
  { status: 'delivered',        label: 'Delivered — enjoy your meal!' },
];

function getTransition(name) {
  return TRANSITIONS[name] || null;
}

/** Simple EDT (estimated delivery time): prep + pickup buffer + Lagos travel avg. */
function computeEta(prepMinutes) {
  const PICKUP_BUFFER_MIN = 5;
  const TRAVEL_MIN = 20;
  const totalMin = (prepMinutes || 20) + PICKUP_BUFFER_MIN + TRAVEL_MIN;
  return new Date(Date.now() + totalMin * 60 * 1000);
}

module.exports = { STATUSES, TRANSITIONS, CLAIMABLE_STATUSES, CUSTOMER_STEPS, getTransition, computeEta };
