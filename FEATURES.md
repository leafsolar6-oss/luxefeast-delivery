# LuxFeast v3.1 — Shop App Feature Pack

Four new features for the shop app (plus the customer app rewiring that makes
menus real). Analyzed clean: `flutter analyze` → 0 errors / 0 warnings on all
three apps (Flutter 3.47.2).

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
