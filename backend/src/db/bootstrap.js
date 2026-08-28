const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { query } = require('../config/db');

/** Incremental migrations — safe to run on every boot (Neon-friendly). */
async function migrate() {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await query(schema);

  // v2.1 — auth & GPS columns
  await query(`
    ALTER TABLE users  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE users  ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE users  ADD COLUMN IF NOT EXISTS entity_id BIGINT;
    ALTER TABLE shops  ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
    ALTER TABLE shops  ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS dropoff_lat DOUBLE PRECISION;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS dropoff_lng DOUBLE PRECISION;

    CREATE TABLE IF NOT EXISTS verification_codes (
      id         BIGSERIAL PRIMARY KEY,
      user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      channel    TEXT NOT NULL CHECK (channel IN ('email','phone')),
      code       TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      consumed   BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_verif_user ON verification_codes (user_id, channel, consumed);
  `);

  // Seed shop coordinates (Lagos / Abuja)
  await query(`UPDATE shops SET lat = 6.4478, lng = 3.4723 WHERE name = 'Mama Nkem Amala Palace' AND lat IS NULL`);
  await query(`UPDATE shops SET lat = 6.4433, lng = 3.4519 WHERE name = 'Jollof Republic Lagos'  AND lat IS NULL`);
  await query(`UPDATE shops SET lat = 9.0765, lng = 7.4713 WHERE name = 'Suya Palace Abuja'      AND lat IS NULL`);
}

async function seed() {
  const { rows } = await query(`SELECT COUNT(*)::int AS n FROM shops`);
  if (rows[0].n === 0) {
    await query(
      `INSERT INTO shops (name, email, phone, address, city, cuisines, rating, avg_prep_minutes, lat, lng) VALUES
       ('Mama Nkem Amala Palace', 'orders@mamankem.ng',   '+2348012345678', 'Plot 17, Lekki Phase 1, Lagos', 'Lagos', '{Amala,"Ewedu & Gbegiri","Swallow & Soup"}', 4.8, 25, 6.4478, 3.4723),
       ('Jollof Republic Lagos',  'hello@jollofrepublic.ng','+2348023456789','12 Admiralty Way, Lekki, Lagos','Lagos', '{"Jollof Rice","Fried Rice","Nigerian Street Food"}', 4.7, 18, 6.4433, 3.4519),
       ('Suya Palace Abuja',      'crew@suyapalace.ng',    '+2348034567890', '3 Aminu Kano Crescent, Wuse 2, Abuja', 'Abuja', '{Suya,Grills,"Pepper Soup"}', 4.9, 15, 9.0765, 7.4713)`
    );
    await query(
      `INSERT INTO users (name, email, phone, address, role) VALUES
       ('Amara Okonkwo', 'customer@luxefeast.com', '+2348011112222', 'Lekki Phase 1, Lagos', 'customer')`
    );
    await query(
      `INSERT INTO riders (name, email, phone, vehicle_type, status, lat, lng) VALUES
       ('Daniel Okoro', 'rider@luxefeast.com',  '+2348033334444', 'Motorcycle', 'available', 6.5244, 3.3792),
       ('Chika Eze',    'chika@luxefeast.com',  '+2348055556666', 'Motorcycle', 'available', 6.4550, 3.4737)`
    );
    console.log('Demo data seeded (3 shops, 1 customer, 2 riders)');
  }

  // v3.1 — seed menus for the demo shops (idempotent).
  const menuCount = await query(`SELECT COUNT(*)::int AS n FROM menu_items`);
  if (menuCount.rows[0].n === 0) {
    await query(
      `INSERT INTO menu_items (shop_id, name, description, price, category, sort_order)
       SELECT s.id, v.name, v.description, v.price, v.category, v.sort_order
       FROM (VALUES
        (1, 'Amala + Ewedu & Gbegiri', 'Classic trio, served piping hot', 3500, 'Mains', 1),
        (1, 'Assorted Goat Meat',      'Slow-stewed, peppered to order',   2000, 'Proteins', 2),
        (1, 'Pounded Yam & Egusi',     'Melon seed soup with ponmo',       3800, 'Mains', 3),
        (1, 'Catfish Pepper Soup',     'Point-and-kill, spicy broth',      4500, 'Soups', 4),
        (1, 'Chapman (1L)',            'The classic Nigerian mocktail',    1500, 'Drinks', 5),
        (2, 'Party Jollof + Chicken',  'Smoky wood-fire party rice',       4200, 'Mains', 1),
        (2, 'Dodo (Fried Plantain)',   'Caramelised, crispy edges',        1200, 'Sides', 2),
        (2, 'Fried Rice & Beef',       'Stir-fried with liver & gizzard',  4500, 'Mains', 3),
        (2, 'Meat Pie',                'Flaky pastry, spiced filling',      800, 'Snacks', 4),
        (2, 'Zobo (50cl)',             'Hibiscus, ginger & pineapple',      700, 'Drinks', 5),
        (3, 'Beef Suya (Full Stick)',  'Yaji-dusted, flame-grilled',       2500, 'Grills', 1),
        (3, 'Masa + Yaji',             'Rice cakes with suya spice',       1500, 'Snacks', 2),
        (3, 'Chicken Suya',            'Thigh fillets, double yaji',      3000, 'Grills', 3),
        (3, 'Goat Pepper Soup',        'Wuse 2 favourite, herbed broth',  4000, 'Soups', 4),
        (3, 'Kunu Aya (50cl)',         'Tiger nut milk, lightly sweet',     800, 'Drinks', 5)
      ) AS v(shop_no, name, description, price, category, sort_order)
      JOIN shops s ON (
        (v.shop_no = 1 AND s.name = 'Mama Nkem Amala Palace') OR
        (v.shop_no = 2 AND s.name = 'Jollof Republic Lagos') OR
        (v.shop_no = 3 AND s.name = 'Suya Palace Abuja')
      )`
    );
    console.log('Demo menus seeded (15 items across 3 shops)');
  }


  // Demo login accounts (password: demo123, pre-verified) — one per role.
  const hash = await bcrypt.hash('demo123', 10);
  const demos = [
    { name: 'Amara Okonkwo', email: 'customer@luxefeast.com', phone: '+2348011112222', role: 'customer', entitySql: null },
    { name: 'Mama Nkem',     email: 'shop@luxefeast.com',     phone: '+2348012345678', role: 'shop',   entitySql: `SELECT id FROM shops WHERE name = 'Mama Nkem Amala Palace'` },
    { name: 'Daniel Okoro',  email: 'rider@luxefeast.com',    phone: '+2348033334444', role: 'rider',  entitySql: `SELECT id FROM riders WHERE name = 'Daniel Okoro'` },
  ];
  for (const d of demos) {
    let entityId = null;
    if (d.entitySql) {
      const r = await query(d.entitySql);
      entityId = r.rows[0]?.id || null;
    }
    await query(
      `INSERT INTO users (name, email, phone, role, password_hash, email_verified, phone_verified, entity_id)
       VALUES ($1,$2,$3,$4,$5,TRUE,TRUE,$6)
       ON CONFLICT (email) DO UPDATE
         SET password_hash = COALESCE(users.password_hash, EXCLUDED.password_hash),
             email_verified = TRUE, phone_verified = TRUE,
             entity_id = COALESCE(users.entity_id, EXCLUDED.entity_id),
             role = EXCLUDED.role`,
      [d.name, d.email, d.phone, d.role, hash, entityId]
    );
  }
  console.log('Demo accounts ready (customer/shop/rider @luxefeast.com, password: demo123)');
}

async function migrateAndSeed() {
  await migrate();
  await seed();
}

module.exports = { migrateAndSeed };
