const { query } = require('../db');

async function getItems(req, res) {
    const categoryId = String(req.query.categoryId || '').trim();
    const search = String(req.query.q || '').trim();

    if (categoryId && !/^\d+$/.test(categoryId)) {
        return res.status(400).json({ message: 'categoryId must be an integer' });
    }

    try {
        const result = await query(
            `SELECT i.*, c.name AS category_name
             FROM items i
             LEFT JOIN categories c ON c.id = i.category_id
             WHERE ($1 = '' OR i.category_id = $1::integer)
               AND ($2 = '' OR i.item_name ILIKE '%' || $2 || '%'
                    OR i.item_code ILIKE '%' || $2 || '%')
             ORDER BY
               CASE
                 WHEN $2 <> '' AND i.item_code ILIKE $2 || '%' THEN 0
                 WHEN $2 <> '' AND i.item_code ILIKE '%' || $2 || '%' THEN 1
                 ELSE 2
               END,
               i.item_name`,
            [categoryId, search],
        );
        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: 'Unable to load items' });
    }
}

async function createItem(req, res) {
    const body = req.body || {};
    const categoryId = Number(body.categoryId);
    const itemName = String(body.itemName || '').trim();
    const unit = String(body.unit || '').trim();
    const rate = Number(body.rate);
    const gst = Number(body.gst);
    const stock = Number(body.stock ?? 0);

    if (!Number.isInteger(categoryId) || categoryId <= 0) {
        return res.status(400).json({ message: 'A valid category is required' });
    }
    if (!itemName || !unit) {
        return res.status(400).json({
            message: 'Item name and unit are required',
        });
    }
    if (![rate, gst, stock].every(Number.isFinite) || rate < 0 || gst < 0 || stock < 0) {
        return res.status(400).json({
            message: 'Rate, GST, and stock must be valid non-negative numbers',
        });
    }

    try {
        const category = await query(
            'SELECT id FROM categories WHERE id = $1',
            [categoryId],
        );
        if (category.rowCount === 0) {
            return res.status(400).json({ message: 'Category does not exist' });
        }

        const existing = await query(
            `SELECT id FROM items
             WHERE category_id = $1
               AND LOWER(BTRIM(item_name)) = LOWER(BTRIM($2))
             LIMIT 1`,
            [categoryId, itemName],
        );
        if (existing.rowCount > 0) {
            return res.status(409).json({ message: 'Item name already exists in this category' });
        }

        const result = await query(
            `INSERT INTO items
                (category_id, item_name, item_code, unit, rate, gst, stock)
             VALUES (
                 $1, $2,
                 'ITEM-' || LPAD(nextval('items_item_code_seq')::text, 6, '0'),
                 $3, $4, $5, $6
             )
             RETURNING *`,
            [categoryId, itemName, unit, rate, gst, stock],
        );

        return res.status(201).json(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({ message: 'Item name or code already exists' });
        }
        return res.status(500).json({ message: 'Unable to create item' });
    }
}

async function updateItem(req, res) {
    const id = Number(req.params.id);
    const body = req.body || {};
    const categoryId = Number(body.categoryId);
    const itemName = String(body.itemName || '').trim();
    const unit = String(body.unit || '').trim();
    const rate = Number(body.rate);
    const gst = Number(body.gst);

    if (!Number.isInteger(id) || id <= 0 ||
        !Number.isInteger(categoryId) || categoryId <= 0 ||
        !itemName || !unit ||
        !Number.isFinite(rate) || rate < 0 ||
        !Number.isFinite(gst) || gst < 0) {
        return res.status(400).json({ message: 'Invalid item details' });
    }

    try {
        const result = await query(
            `UPDATE items
                 SET category_id = $1, item_name = $2,
                     unit = $3, rate = $4, gst = $5
                 WHERE id = $6
             RETURNING *`,
                [categoryId, itemName, unit, rate, gst, id],
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Item not found' });
        }
        return res.json(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({ message: 'Item name or code already exists' });
        }
        return res.status(500).json({ message: 'Unable to update item' });
    }
}

async function deleteItem(req, res) {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
        return res.status(400).json({ message: 'Invalid item id' });
    }

    try {
        const result = await query(
            'DELETE FROM items WHERE id = $1 RETURNING id',
            [id],
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Item not found' });
        }
        return res.json({ message: 'Item deleted successfully' });
    } catch (error) {
        if (error.code === '23503') {
            return res.status(409).json({ message: 'Item is already used and cannot be deleted' });
        }
        return res.status(500).json({ message: 'Unable to delete item' });
    }
}

module.exports = { getItems, createItem, updateItem, deleteItem };
