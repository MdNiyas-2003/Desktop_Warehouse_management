const { query } = require('../db');

async function getSupplierInvoices(req, res) {
    try {
        const result = await query(
            `SELECT si.id, si.invoice_no, si.grand_total, si.invoice_date, COALESCE(SUM(p.amount), 0) AS paid_amount, GREATEST(si.grand_total - COALESCE(SUM(p.amount), 0), 0) AS remaining_amount FROM supplier_invoices si LEFT JOIN payments p ON p.supplier_id = si.id WHERE si.supplier_name = $1 GROUP BY si.id ORDER BY si.invoice_date DESC`,
            [req.params.supplierName],
        );

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

module.exports = { getSupplierInvoices };
