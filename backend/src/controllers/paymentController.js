const { query } = require('../db');

async function getPayments(_req, res) {
    try {
        const result = await query(`SELECT p.*, COALESCE(c.company_name, s.supplier_name, '') AS party_name, COALESCE(o.order_code, s.invoice_no, '') AS invoice_no FROM payments p LEFT JOIN customers c ON c.id = p.customer_id LEFT JOIN supplier_invoices s ON s.id = p.supplier_id LEFT JOIN orders o ON o.id = p.invoice_id ORDER BY payment_date DESC`);

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function createPayment(req, res) {
    const {
        voucher_no = '',
        customer_id = null,
        supplier_id = null,
        invoice_id = null,
        payment_date,
        payment_method = '',
        reference_no = '',
        cheque_no = '',
        cheque_date = null,
        amount = 0,
        notes = '',
        status = 'Paid',
    } = req.body;

    try {
        const result = await query(
            `INSERT INTO payments ( voucher_no, customer_id, supplier_id, invoice_id, payment_date, payment_method, reference_no, cheque_no, cheque_date, amount, notes, status ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *;`,
            [
                voucher_no,
                customer_id,
                supplier_id,
                invoice_id,
                payment_date,
                payment_method,
                reference_no,
                cheque_no,
                cheque_date,
                amount,
                notes,
                status,
            ],
        );

        return res.status(201).json(result.rows[0]);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function getCustomerPayments(req, res) {
    try {
        const result = await query(
            `SELECT * FROM payments WHERE customer_id=$1 ORDER BY payment_date ASC`,
            [req.params.customerId],
        );

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

module.exports = {
    getPayments,
    createPayment,
    getCustomerPayments,
};