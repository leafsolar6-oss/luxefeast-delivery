const express = require('express');
const router = express.Router();
const { query } = require('../config/db');

// Reject non-numeric :id / :itemId up front.
router.param('id', (req, res, next, id) => {
  if (!/^\d+$/.test(id)) return res.status(400).json({ message: 'Invalid shop id' });
  next();
});
router.param('itemId', (req, res, next, itemId) => {
  if (!/^\d+$/.test(itemId)) return res.status(400).json({ message: 'Invalid menu item id' });
  next();
});

// ------------------------------------------------------------- shop list ---

router.get('/', async (_req, res) => {
  try {
    const { rows } = await query(`SELECT * FROM shops WHERE is_open = TRUE ORDER BY rating DESC`);
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.get('/:id', async (req, res) => {
  try {
    const { rows } = await query(`SELECT * FROM shops WHERE id = $1`, [req.params.id]);
    if (!rows[0]) return res.status(404).json({ message: 'Shop not found' });
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Update shop profile / availability (shop app → Settings screen).
router.patch('/:id', async (req, res) => {
  try {
    const { name, phone, address, city, cuisines, avgPrepMinutes, isOpen } = req.body;
    const sets = [], params = [];
    const add = (col, val) => { params.push(val); sets.push(`${col} = $${params.length}`); };

    if (typeof name === 'string' && name.trim()) add('name', name.trim());
    if (phone !== undefined) add('phone', phone);
    if (typeof address === 'string' && address.trim()) add('address', address.trim());
    if (typeof city === 'string' && city.trim()) add('city', city.trim());
    if (Array.isArray(cuisines)) add('cuisines', cuisines.map(String));
    if (avgPrepMinutes !== undefined) {
      const m = Number(avgPrepMinutes);
      if (!Number.isFinite(m) || m < 5 || m > 180) {
        return res.status(400).json({ message: 'avgPrepMinutes must be 5–180' });
      }
      add('avg_prep_minutes', Math.round(m));
    }
    if (isOpen !== undefined) add('is_open', Boolean(isOpen));

    if (!sets.length) return res.status(400).json({ message: 'Nothing to update' });

    const { rows } = await query(
      `UPDATE shops SET ${sets.join(', ')} WHERE id = $${params.length + 1} RETURNING *`,
      [...params, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ message: 'Shop not found' });
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// ------------------------------------------------------------------ menu ---

// Public menu for a shop (customer app) — available items only by default.
// ?includeUnavailable=1 returns everything (shop app manager view).
router.get('/:id/menu', async (req, res) => {
  try {
    const all = ['1', 'true', 'yes'].includes(String(req.query.includeUnavailable ?? '').toLowerCase());
    const { rows } = await query(
      `SELECT id, shop_id, name, description, price, category, image_url,
              is_available, sort_order
         FROM menu_items
        WHERE shop_id = $1 ${all ? '' : 'AND is_available = TRUE'}
        ORDER BY sort_order, id`,
      [req.params.id]
    );
    res.json(rows);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

function validItem(body) {
  const name = String(body.name ?? '').trim();
  const price = Number(body.price);
  if (!name) return { error: 'Item name is required' };
  if (!Number.isFinite(price) || price < 0) return { error: 'Price must be a positive number' };
  return {
    name,
    description: body.description ? String(body.description).trim() : null,
    price,
    category: body.category ? String(body.category).trim() : 'Mains',
    image_url: body.imageUrl ? String(body.imageUrl).trim() : null,
    is_available: body.isAvailable === undefined ? true : Boolean(body.isAvailable),
    sort_order: Number(body.sortOrder) || 0,
  };
}

// Add a menu item.
router.post('/:id/menu', async (req, res) => {
  try {
    const item = validItem(req.body);
    if (item.error) return res.status(400).json({ message: item.error });
    const { rows } = await query(
      `INSERT INTO menu_items (shop_id, name, description, price, category, image_url, is_available, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.params.id, item.name, item.description, item.price, item.category, item.image_url,
       item.is_available, item.sort_order]
    );
    res.status(201).json(rows[0]);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Edit a menu item (price, name, availability, …).
router.put('/:id/menu/:itemId', async (req, res) => {
  try {
    const current = await query(
      `SELECT * FROM menu_items WHERE id = $1 AND shop_id = $2`,
      [req.params.itemId, req.params.id]
    );
    if (!current.rows[0]) return res.status(404).json({ message: 'Menu item not found' });

    // Partial update: anything provided replaces the stored value.
    const cur = current.rows[0];
    const body = {
      name: cur.name,
      description: cur.description,
      price: cur.price,
      category: cur.category,
      imageUrl: cur.image_url,
      isAvailable: cur.is_available,
      sortOrder: cur.sort_order,
      ...req.body,
    };
    const item = validItem(body);
    if (item.error) return res.status(400).json({ message: item.error });

    const { rows } = await query(
      `UPDATE menu_items
          SET name = $1, description = $2, price = $3, category = $4,
              image_url = $5, is_available = $6, sort_order = $7
        WHERE id = $8 AND shop_id = $9 RETURNING *`,
      [item.name, item.description, item.price, item.category, item.image_url,
       item.is_available, item.sort_order, req.params.itemId, req.params.id]
    );
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Remove a menu item.
router.delete('/:id/menu/:itemId', async (req, res) => {
  try {
    const { rowCount } = await query(
      `DELETE FROM menu_items WHERE id = $1 AND shop_id = $2`,
      [req.params.itemId, req.params.id]
    );
    if (!rowCount) return res.status(404).json({ message: 'Menu item not found' });
    res.json({ message: 'Menu item deleted' });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// ------------------------------------------------------------------ stats ---

// Earnings & activity summary for the shop app → Earnings tab.
router.get('/:id/stats', async (req, res) => {
  try {
    const shopId = req.params.id;

    const [revenue, counts, prep, topItems] = await Promise.all([
      query(
        `SELECT
           COALESCE(SUM(total) FILTER (WHERE status = 'delivered' AND delivered_at::date = now()::date), 0) AS revenue_today,
           COALESCE(SUM(total) FILTER (WHERE status = 'delivered'), 0)                          AS revenue_all_time,
           COUNT(*) FILTER (WHERE placed_at::date = now()::date)                                 AS orders_today,
           COUNT(*)                                                                              AS orders_all_time
         FROM orders WHERE shop_id = $1`,
        [shopId]
      ),
      query(
        `SELECT status, COUNT(*)::int AS n FROM orders WHERE shop_id = $1 GROUP BY status`,
        [shopId]
      ),
      query(
        `SELECT COALESCE(AVG(prep_minutes), 0)::numeric(5,1) AS avg_prep_minutes,
               COALESCE(AVG(EXTRACT(EPOCH FROM (ready_at - accepted_at))/60) FILTER (WHERE ready_at IS NOT NULL AND accepted_at IS NOT NULL), 0)::numeric(5,1) AS avg_actual_prep
           FROM orders WHERE shop_id = $1 AND status IN ('delivered','ready_for_pickup','picked_up','in_transit','arrived')`,
        [shopId]
      ),
      query(
        `SELECT item->>'name' AS name,
                SUM((item->>'quantity')::int) AS qty,
                SUM((item->>'price')::numeric * COALESCE((item->>'quantity')::int, 1)) AS revenue
           FROM orders o, jsonb_array_elements(o.items) AS item
          WHERE o.shop_id = $1 AND o.status NOT IN ('rejected','cancelled')
          GROUP BY 1 ORDER BY qty DESC LIMIT 5`,
        [shopId]
      ),
    ]);

    const byStatus = {};
    counts.rows.forEach((r) => byStatus[r.status] = r.n);

    res.json({
      revenueToday: revenue.rows[0].revenue_today,
      revenueAllTime: revenue.rows[0].revenue_all_time,
      ordersToday: revenue.rows[0].orders_today,
      ordersAllTime: revenue.rows[0].orders_all_time,
      byStatus,
      avgPrepMinutes: prep.rows[0].avg_prep_minutes,
      avgActualPrepMinutes: prep.rows[0].avg_actual_prep,
      topItems: topItems.rows.map((r) => ({
        name: r.name, quantity: Number(r.qty), revenue: r.revenue,
      })),
    });
  } catch (e) { res.status(500).json({ message: e.message }); }
});

module.exports = router;
