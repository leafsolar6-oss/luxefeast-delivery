-- LuxFeast — Postgres schema (Neon-compatible)
-- Three-sided marketplace: customers, shops, riders + order lifecycle audit.

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  phone         TEXT,
  address       TEXT,
  role          TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','shop','rider','admin')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shops (
  id               BIGSERIAL PRIMARY KEY,
  name             TEXT NOT NULL,
  email            TEXT UNIQUE NOT NULL,
  phone            TEXT,
  address          TEXT NOT NULL,
  city             TEXT NOT NULL DEFAULT 'Lagos',
  cuisines         TEXT[] NOT NULL DEFAULT '{}',
  rating           NUMERIC(2,1) NOT NULL DEFAULT 4.5,
  is_open          BOOLEAN NOT NULL DEFAULT TRUE,
  avg_prep_minutes INT NOT NULL DEFAULT 20,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS riders (
  id             BIGSERIAL PRIMARY KEY,
  name           TEXT NOT NULL,
  email          TEXT UNIQUE NOT NULL,
  phone          TEXT,
  vehicle_type   TEXT NOT NULL DEFAULT 'Motorcycle',
  status         TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('available','on_delivery','offline')),
  lat            DOUBLE PRECISION,
  lng            DOUBLE PRECISION,
  rating         NUMERIC(2,1) NOT NULL DEFAULT 5.0,
  total_earnings NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id                BIGSERIAL PRIMARY KEY,
  code              TEXT UNIQUE NOT NULL,
  customer_id       BIGINT NOT NULL REFERENCES users(id),
  shop_id           BIGINT NOT NULL REFERENCES shops(id),
  rider_id          BIGINT REFERENCES riders(id),
  items             JSONB NOT NULL,
  subtotal          NUMERIC(12,2) NOT NULL,
  delivery_fee      NUMERIC(12,2) NOT NULL DEFAULT 850,
  service_fee       NUMERIC(12,2) NOT NULL DEFAULT 200,
  total             NUMERIC(12,2) NOT NULL,
  currency          TEXT NOT NULL DEFAULT 'NGN',
  payment_gateway   TEXT NOT NULL DEFAULT 'paystack' CHECK (payment_gateway IN ('paystack','flutterwave','cash')),
  payment_status    TEXT NOT NULL DEFAULT 'authorized' CHECK (payment_status IN ('pending','authorized','paid','refunded')),
  status            TEXT NOT NULL DEFAULT 'placed' CHECK (status IN
                      ('placed','accepted','rejected','preparing','ready_for_pickup',
                       'picked_up','in_transit','arrived','delivered','cancelled')),
  delivery_address  TEXT NOT NULL,
  prep_minutes      INT,
  eta               TIMESTAMPTZ,
  placed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at       TIMESTAMPTZ,
  ready_at          TIMESTAMPTZ,
  rider_assigned_at TIMESTAMPTZ,
  rider_at_shop_at  TIMESTAMPTZ,
  picked_up_at      TIMESTAMPTZ,
  delivered_at      TIMESTAMPTZ,
  cancelled_at      TIMESTAMPTZ,
  cancel_reason     TEXT,
  version           INT NOT NULL DEFAULT 1,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Immutable audit trail of every lifecycle event (who did what, when).
CREATE TABLE IF NOT EXISTS order_events (
  id          BIGSERIAL PRIMARY KEY,
  order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  actor       TEXT NOT NULL,             -- 'customer' | 'shop' | 'rider' | 'system'
  event       TEXT NOT NULL,             -- e.g. 'order:accepted'
  from_status TEXT,
  to_status   TEXT,
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rider_payments (
  id         BIGSERIAL PRIMARY KEY,
  rider_id   BIGINT NOT NULL REFERENCES riders(id),
  order_id   BIGINT NOT NULL REFERENCES orders(id),
  amount     NUMERIC(12,2) NOT NULL,
  status     TEXT NOT NULL DEFAULT 'paid',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_shop    ON orders (shop_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_rider   ON orders (rider_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_order   ON order_events (order_id, created_at);

-- v3.1 — shop-managed menus (replaces hardcoded menus in the customer app).
CREATE TABLE IF NOT EXISTS menu_items (
  id           BIGSERIAL PRIMARY KEY,
  shop_id      BIGINT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  description  TEXT,
  price        NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  category     TEXT NOT NULL DEFAULT 'Mains',
  image_url    TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_menu_shop ON menu_items (shop_id, is_available, sort_order);
