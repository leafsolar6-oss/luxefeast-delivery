# LuxFeast v3.2 — Shop App Feature Pack + Guest Browsing & Cart

**v3.2 additions:** the customer app is now **browse-first** — menus open
immediately on launch, no account needed. An account is only required at
checkout, and there's a proper **cart** (persisted on-device, one shop at a
time). Widget tests pass; `flutter analyze` → 0 errors / 0 warnings on all
three apps (Flutter 3.47.2).

---

## 5. 🛒 Guest browsing + cart (customer app)

- **No login wall**: the app opens straight to the restaurant list & menus.
  A stored session (if any) restores quietly in the background.
- **Cart** (`CartService`): add items from any menu with quantity steppers;
  the cart survives app restarts (SharedPreferences) and belongs to one shop
  at a time — adding from a different shop asks before starting a fresh cart.
- **Cart UI**: bag icon with live count badge in the app bar; cart sheet with
  per-item steppers, subtotal + delivery (₦850) + service (₦200) + total.
- **Sign in only to order**: tapping *Place order* while a guest opens the
  auth screen ("Sign in to place your order"); after login the order is
  placed automatically and live tracking starts.
- **Account button**: person icon for guests (sign in), logout icon for users
  (with confirmation; the cart is kept).
- Fixed a pre-existing header layout overflow (60px → 40px padding) caught
  by the new widget test.

---

## 1. 🍔 Menu Manager (full stack)

Shops now control what customers can order. The customer app no longer uses a
hardcoded menu — it browses each shop's live menu.

**Backend**
- New `menu_items` table (auto-migrated on boot; demo menus seeded for the 3 shops).
- `GET    /api/shops/:id/menu` — public menu (available items only)
- `GET    /api/shops/:id/menu?includeUnavailable=1` — manager view
- `POST   /api/shops/:id/menu` — add item `{name, price, description?, category?}`
- `PUT    /api/shops/:id/menu/:itemId` — partial edit (also `isAvailable` toggle)
- `DELETE /api/shops/:id/menu/:itemId`

**Shop app → Menu tab**: items grouped by category, availability switch per item
(hidden items instantly disappear from the customer app), add/edit form with
category chips, delete with confirmation.

**Customer app**: tapping a restaurant now opens its **live menu sheet** —
browse items, add quantities, see subtotal + fees, place order → tracking.

## 2. 💰 Earnings & Order History (shop app → Earnings tab)

- `GET /api/shops/:id/stats` — revenue today / all-time, orders today /
  all-time, counts by status, average prep time (promised vs actual), best sellers.
- Revenue hero card + stat tiles, best-sellers list, filterable history
  (All / Delivered / Cancelled / Rejected) — tap any order for full detail.

## 3. ⚙️ Shop Profile & Availability (shop app → Settings tab)

- `PATCH /api/shops/:id` — update name, phone, address, city, cuisines,
  `avgPrepMinutes`, and `isOpen`.
- **Open/Closed switch** — closing the shop hides it from the customer app
  instantly (`GET /api/shops` only returns `is_open = TRUE`). The Orders tab
  shows a red "You are CLOSED" banner with a one-tap reopen.
- Editable profile form + default prep-time slider (pre-fills the accept dialog).

## 4. 🔔 Smarter Order Handling (shop app → Orders tab)

- **New-order alert**: system sound + double vibration + banner.
- **Itemized order cards**: every line item with quantity & price, customer
  name/phone, red border for new (unaccepted) orders.
- **Accept flow**: prep-time slider dialog (default from shop settings) instead
  of a blind 20-minute accept.
- **Order detail sheet**: tap any order → full receipt (items, fees, total,
  customer, rider) + live event timeline.

## App shell

The shop app now has bottom navigation: **Orders · Menu · Earnings · Settings**
(`IndexedStack` — the live order socket keeps running across tabs).

---

## Build (on your machine)

```bash
# backend (no changes needed beyond v3.0 fix — deploy triggers on push)
# apps:
cd shop_app    && flutter pub get && flutter build apk --release \
  --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
cd ../customer_app && flutter pub get && flutter build apk --release \
  --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
```

## Backend deploy

Push to `main` → Render auto-deploys. On boot it runs the migration (creates
`menu_items`) and seeds demo menus once (only if the table is empty).
