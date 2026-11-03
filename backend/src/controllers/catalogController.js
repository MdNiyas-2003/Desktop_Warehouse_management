const { query } = require('../db');

async function getCatalog(_req, res) {
    try {
        const result = await query(
            `SELECT id, category, item_name, sku, rate FROM catalog_items ORDER BY category, item_name`,
        );

        return res.json(
            result.rows.map((row) => ({
                id: row.id,
                category: row.category,
                itemName: row.item_name,
                sku: row.sku,
                rate: Number(row.rate),
            })),
        );
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function createCatalog(req, res) {
    const { category = 'General', itemName, sku = '', rate = 0 } = req.body || {};

    if (!itemName || String(itemName).trim().length === 0) {
        return res.status(400).json({ message: 'itemName is required' });
    }

    try {
        const result = await query(
            `INSERT INTO catalog_items (category, item_name, sku, rate) VALUES ($1, $2, $3, $4) RETURNING id, category, item_name, sku, rate`,
            [category, itemName, sku || itemName, Number(rate) || 0],
        );

        const row = result.rows[0];
        return res.status(201).json({
            id: row.id,
            category: row.category,
            itemName: row.item_name,
            sku: row.sku,
            rate: Number(row.rate),
        });
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

module.exports = { getCatalog, createCatalog };