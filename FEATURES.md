# LuxFeast v3.4 — Pop-up Notifications

**v3.4:** pop-up notifications across all three apps — slide-in banners over
any screen, plus a full-screen NEW ORDER popup for the shop and a Claim popup
for riders. Works while each app is in the foreground; no permissions needed.

- **Shared `PopupNotifier`** (per app): animated top banners with icon, title,
  message, optional action button; auto-dismiss; tap-through actions; max 3
  stacked; sound + vibration for critical events.
- **Shop app**: NEW ORDER = full-screen popup (sound + double vibration) with
  items, total and one-tap **Accept / Reject / View**. Rider assigned, rider
  at shop, picked up, delivered, cancelled → banners.
- **Customer app**: popups for every order status change (accepted, preparing,
  ready, rider assigned, picked up, in transit, arrived, delivered,
  cancelled/rejected) — tap to open live tracking. Popups are suppressed for
  the order you're already watching. Fixed a latent double-socket leak on
  re-login.
- **Rider app**: delivery offers pop up with sound + a **Claim** button
  (claims straight from the popup, handles the "too slow" case), plus banners
  for ready-for-pickup, payout, cancelled.

Verified end-to-end (v2-protocol clients = the real APK protocol): shop
received `order:placed`, rider received `delivery:offer`, customer received
`order:accepted`. `flutter analyze`: 0 errors/warnings ×3; tests passing.

---

# LuxFeast v3.3 — Nature Fete Rebrand

**v3.3:** the business is now **Nature Fete** 🌿 — parfaits, fruit juices,
smoothies & healthy bowls, with a fresh **green & white** theme across all
three apps. Deployed & verified on production.

- Shop renamed (one-time migration, idempotent): *Mama Nkem Amala Palace* →
  **Nature Fete** · cuisines: Parfaits / Fruit Juices / Smoothies / Healthy
  Bowls · 15-min default prep · ⭐ 4.9
- Menu swapped to 13 fresh items: 3 parfaits, 3 juices, 2 smoothies, 2 bowls,
  avocado toast, coconut water, energy bites
- Demo shop login renamed to 'Nature Fete' (same credentials:
  shop@luxefeast.com / demo123)
- All three apps re-themed: deep green #1E7B47 + white surfaces (light mode)
- Customer app: Nature Fete branding + 'Fresh From Our Kitchen' header
- Template demo shops (Jollof Republic, Suya Palace) closed on production so
  customers see only Nature Fete — reopen anytime via PATCH /api/shops/2|3
  {"isOpen": true} or delete their seed rows on a fresh install

---

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
