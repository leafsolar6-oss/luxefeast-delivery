# LuxFeast — Order Lifecycle & Real-Time Choreography

International-standard three-sided food delivery process (modeled on the Uber Eats /
DoorDash order journey), running on **Postgres (Neon)** with Socket.IO real-time events.

## The State Machine

```
                         ┌──────────┐
      customer places →  │  PLACED  │ ──→ REJECTED (shop, refund)
                         └────┬─────┘ ──→ CANCELLED (customer, refund)
                    shop accepts (+prep ETA)
                         ┌────▼─────┐
                         │ ACCEPTED │ ──→ CANCELLED (customer)
                         └────┬─────┘        ┌─────────────────────────────┐
                    kitchen starts           │  PARALLEL DISPATCH          │
                         ┌────▼─────┐        │  delivery:offer → riders    │
                         │PREPARING │        │  first rider to claim wins  │
                         └────┬─────┘        │  (atomic, no double-assign) │
                    kitchen done             └─────────────────────────────┘
                    ┌────────▼────────┐
                    │READY_FOR_PICKUP │  ← rider arrives at shop (rider:at_shop)
                    └────────┬────────┘
                    rider confirms pickup
                        ┌────▼──────┐
                        │ PICKED_UP │
                        └────┬──────┘
                        ┌────▼──────┐
                        │IN_TRANSIT │  ← rider streams GPS (rider:location)
                        └────┬──────┘
                        ┌────▼────┐
                        │ ARRIVED │
                        └────┬────┘
                        ┌────▼──────┐
                        │ DELIVERED │  → payment settled, rider paid ₦ delivery fee,
                        └───────────┘    rider freed for the next offer
```

**Concurrency safety** (the DoorDash pattern): every transition runs as
`UPDATE … WHERE status = expected` — a stale or racing update simply gets **409**.
Rider claims use `WHERE rider_id IS NULL`, so exactly one rider can win. Every
transition is appended to the immutable `order_events` audit table.

## Who gets alerted, and when

| Event               | Customer | Shop | Assigned rider | All available riders |
|---------------------|:--------:|:----:|:--------------:|:--------------------:|
| `order:placed`      |          | 🔔   |                |                      |
| `order:accepted`    | 🔔       |      |                |                      |
| `delivery:offer`    |          |      |                | 🔔                   |
| `rider:assigned`    | 🔔       | 🔔   | 🔔             | `delivery:taken`     |
| `order:preparing`   | 🔔       |      |                |                      |
| `order:ready`       | 🔔       |      | 🔔             |                      |
| `rider:at_shop`     | 🔔       | 🔔   |                |                      |
| `order:picked_up`   | 🔔       | 🔔   |                |                      |
| `order:in_transit`  | 🔔       |      |                |                      |
| `rider:location`    | 🔔 (map) |      |                |                      |
| `order:arrived`     | 🔔       |      |                |                      |
| `order:delivered`   | 🔔       | 🔔   | 🔔 (payout)    |                      |
| `order:cancelled`   | 🔔       | 🔔   | 🔔 (if any)    |                      |

## REST API (drives the transitions)

| Actor    | Endpoint                              | Effect |
|----------|---------------------------------------|--------|
| Customer | `POST /api/orders`                    | place order → shop alerted |
| Customer | `POST /api/orders/:id/cancel`         | cancel (only before prep) → refund |
| Shop     | `POST /api/orders/:id/accept`         | accept + prep ETA → customer + rider offers |
| Shop     | `POST /api/orders/:id/reject`         | reject → customer refunded |
| Shop     | `POST /api/orders/:id/preparing`      | kitchen started |
| Shop     | `POST /api/orders/:id/ready`          | packed → rider urged to pick up |
| Rider    | `POST /api/orders/:id/claim`          | atomic first-come claim |
| Rider    | `POST /api/orders/:id/arrive-shop`    | at restaurant |
| Rider    | `POST /api/orders/:id/pickup`         | confirms pickup (assigned rider only) |
| Rider    | `POST /api/orders/:id/in-transit`     | heading to customer |
| Rider    | `POST /api/orders/:id/arrive-customer`| at the door |
| Rider    | `POST /api/orders/:id/deliver`        | done → settle payment, pay rider |
| Rider    | `GET  /api/orders/available-deliveries` | open offers feed |
| Rider    | `GET  /api/riders/:id/earnings`       | ₦ payout history |

## Using Neon

1. Create a free project at [neon.tech](https://neon.tech) (region: choose closest, e.g. AWS eu-central).
2. Copy the connection string from the Neon dashboard.
3. In `backend/.env`:
   ```
   DATABASE_URL=postgresql://USER:PASSWORD@ep-xxxx.eu-central-1.aws.neon.tech/luxefeast?sslmode=require
   ```
4. `npm start` — the schema migrates and seeds automatically on first boot.

SSL is auto-enabled when a Neon URL is detected. The same code runs against any
Postgres (local dev uses `postgresql://luxefeast:luxefeast@localhost:5432/luxefeast`).

## Verifying the choreography

```bash
cd backend
npm install
npm start            # terminal 1
npm run test:flow    # terminal 2 — simulates customer + shop + 2 racing riders
```

The simulation places an order, has the shop accept, lets two riders race to claim
(asserting exactly one wins), walks pickup → transit → GPS → delivered, and verifies
every party received every alert plus the rider's ₦850 payout.

## Flutter apps

Each app's `SocketService` registers its role on connect
(`register {role, id}`) and exposes typed listeners for exactly the events that
role must react to. Point the apps at your backend at build time:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-host
```
