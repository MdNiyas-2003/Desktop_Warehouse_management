const { query } = require('../db');

async function getSuppliers(req, res) {
    const search = String(req.query.q || '').trim();

    try {
        const result = await query(
            `SELECT
                s.id,
                s.supplier_name,
                s.supplier_code,
                s.supplier_contact,
                s.supplier_phone,
                s.supplier_gstin,
                s.supplier_address,
                s.supplier_location,
                COALESCE(SUM(GREATEST(si.grand_total - COALESCE(paid.amount, 0), 0)), 0) AS outstanding_balance
             FROM suppliers s
             LEFT JOIN supplier_invoices si
               ON LOWER(BTRIM(si.supplier_name)) = LOWER(BTRIM(s.supplier_name))
             LEFT JOIN LATERAL (
                 SELECT SUM(p.amount) AS amount
                 FROM payments p
                 WHERE p.supplier_id = si.id
             ) paid ON TRUE
             WHERE $1 = '' OR
               s.supplier_name ILIKE '%' || $1 || '%' OR
               s.supplier_code ILIKE '%' || $1 || '%' OR
               s.supplier_phone ILIKE '%' || $1 || '%'
             GROUP BY s.id
             ORDER BY s.supplier_name`,
            [search],
        );

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: 'Unable to load suppliers' });
    }
}

async function createSupplier(req, res) {
    const body = req.body || {};
    const name = String(body.name ?? body.supplier_name ?? '').trim();

    if (!name) {
        return res.status(400).json({ message: 'Supplier name is required' });
    }

    const values = [
        name,
        String(body.code ?? body.supplier_code ?? '').trim(),
        String(body.contact ?? body.supplier_contact ?? '').trim(),
        String(body.phone ?? body.supplier_phone ?? '').trim(),
        String(body.gstin ?? body.supplier_gstin ?? '').trim(),
        String(body.address ?? body.supplier_address ?? '').trim(),
        String(body.location ?? body.supplier_location ?? '').trim(),
    ];

    try {
        const existing = await query(
            `SELECT id FROM suppliers
             WHERE LOWER(BTRIM(supplier_name)) = LOWER(BTRIM($1))
             LIMIT 1`,
            [name],
        );
        if (existing.rowCount > 0) {
            return res.status(409).json({ message: 'Supplier already exists' });
        }

        const result = await query(
            `INSERT INTO suppliers (
                supplier_name, supplier_code, supplier_contact, supplier_phone,
                supplier_gstin, supplier_address, supplier_location
             ) VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, supplier_name, supplier_code, supplier_contact,
                       supplier_phone, supplier_gstin, supplier_address,
                       supplier_location`,
            values,
        );

        return res.status(201).json({
            ...result.rows[0],
            outstanding_balance: 0,
        });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({ message: 'Supplier already exists' });
        }
        return res.status(500).json({ message: 'Unable to create supplier' });
    }
}

module.exports = { getSuppliers, createSupplier };
