# LuxFeast — Real-time fix (shop not receiving orders)

## Root cause
All three Flutter apps ship `socket_io_client: ^2.0.3+1` (Socket.IO **v2** protocol).
The backend runs `socket.io: ^4.7.5` (protocol **v4**). These are incompatible, so the
apps' socket connections silently never open — no `order:placed` alerts for the shop,
no live tracking for the customer, no delivery offers / GPS stream for the rider.

## Fixes (this patch)
1. **`backend/src/server.js`** — `allowEIO3: true` on the Socket.IO server.
   Lets the already-released v2-protocol APKs connect. No rebuild needed.
2. **`backend/src/server.js`** — `express-async-errors` + JSON error middleware.
   Previously ANY unhandled async route error (e.g. `/api/orders/null`) crashed the
   whole process, dropping every socket. Now returns a clean 400/500.
3. **`backend/src/routes/orders.js`** — `router.param('id')` validation: non-numeric
   order ids return `400 Invalid order id` instead of a Postgres bigint parse crash.
4. **`shop_app`, `customer_app`, `rider_app` pubspec.yaml** — `socket_io_client: ^3.1.6`
   (native Socket.IO v4 support, same API). Rebuild APKs at the next release:
   `flutter pub get && flutter build apk --release --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com`

## Verification (all passed)
- v2-protocol client (identical to the shop APK) → connects, registers `shop:1`,
  **receives `order:placed` in real time** when a customer places an order.
- Customer client receives `order:accepted` in real time after the shop accepts.
- `GET /api/orders/null` / `POST /api/orders/abc/accept` → HTTP 400, server stays healthy.
- Control test: against the unfixed Render deployment, the v2 client never connects
  (confirmed the bug is live in production until this patch is deployed).

## Deploy
```
git apply luxefeast-realtime-fix.patch
git add -A && git commit -m "fix: Socket.IO v2 client compat (allowEIO3) + async error hardening"
git push   # Render auto-deploys the backend
```
After Render redeploys, the existing v3.0.0 APKs receive real-time events immediately.

## Note for testing
The demo shop login (`shop@luxefeast.com` / `demo123`) owns **Mama Nkem Amala Palace**
(shop 1). Orders placed from *Jollof Republic* or *Suya Palace* go to those shops and
will never appear on that account — test by ordering from Mama Nkem in the customer app.
