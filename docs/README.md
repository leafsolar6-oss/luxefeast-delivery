# LuxFeast — International Standard Food Delivery Ecosystem

A premium, three-sided food delivery platform built to international quality standards.

## Architecture

```
LuxFeast/
├── backend/              # Node.js + Express + Socket.IO + MongoDB
│   ├── src/server.js     # Real-time WebSocket server
│   └── src/routes/        # REST APIs for orders, shops, riders
├── customer_app/         # Flutter — Customer ordering & real-time tracking
├── shop_app/             # Flutter — Shop dashboard & order management
├── rider_app/            # Flutter — Rider notifications, updates, payments
└── shared/               # Shared design tokens & utilities
```

## International Standards Applied

- **Accessibility (WCAG 2.1 AA)**: High-contrast luxury dark palette (`#0A0A0F` / `#D4AF37`), semantic typography (`Playfair Display` + `Inter`), keyboard navigation support.
- **Responsive Design**: All Flutter apps use `LayoutBuilder` and adaptive grids; web backend serves mobile-friendly JSON.
- **Real-Time Communication**: WebSocket (`socket.io`) with automatic reconnection, ping timeouts (60s), and event-based order tracking.
- **Security**: `helmet`, `cors`, `bcryptjs` password hashing, `JWT` authentication, environment variable isolation.
- **Performance**: Flutter `CustomScrollView` with `SliverAppBar`, lazy-loaded grids, image caching via `NetworkImage`. Backend uses `morgan` logging and `mongoose` indexing.
- **Internationalization (i18n)**: `intl` package integrated; all date/time formats use locale-aware strings; currency symbols are parameterized (`₦` for NGN, `USD`, `EUR`, etc.).
- **Payment Readiness**: Stripe SDK included in backend; payment history modeled in `Rider` collection; ready for PCI-compliant integration.
- **Code Quality**: `eslint`, `flutter_lints`, `prettier`-ready formatting, modular architecture (controllers, routes, services, screens, widgets).

## Design System — Luxury Dark Theme

- **Palette**: Deep Black (`#0A0A0F`), Gold (`#D4AF37`), Surface (`#12121A`), Elevated (`#181825`).
- **Typography**: `Playfair Display` (display/headlines — luxury editorial feel), `Inter` (UI/body — clean international readability).
- **Components**: Glassmorphic cards with gold 10% borders, rounded 24px corners, shimmer loading states, linear progress tracking, floating action buttons.

## Running the System

### 1. Backend
```bash
cd backend
npm install
npm run dev
```

### 2. Customer App
```bash
cd customer_app
flutter pub get
flutter run
```

### 3. Shop App
```bash
cd shop_app
flutter pub get
flutter run
```

### 4. Rider App
```bash
cd rider_app
flutter pub get
flutter run
```

## Real-Time Flow

1. Customer places order → `POST /api/orders`
2. Shop sees new order in dashboard → updates status via `PUT /api/orders/:id/status`
3. Socket event broadcasts to customer tracking screen (`join-order` room)
4. Rider receives notification and updates delivery status → `emit('update-order-status')`
5. Customer sees live progress bar and step updates in real time.

## Pushing to GitHub

This repo is already initialized (`git init`, branch `main`).

```bash
# 1. Create a new repo on GitHub (e.g., luxefeast-delivery)
# 2. Add remote
git remote add origin https://github.com/YOUR_USERNAME/luxefeast-delivery.git

# 3. Commit everything
git add .
git commit -m "feat: initial release — customer, shop, rider apps + backend"

# 4. Push
git push -u origin main
```

## License
MIT — Built for global scale.
