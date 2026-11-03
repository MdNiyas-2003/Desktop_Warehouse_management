const { pool } = require('../db');

async function createBill(req, res) {
    const {
        billNumber,
        customerId = null,
        billDate = null,
        subtotal = 0,
        discountAmount = 0,
        gstAmount = 0,
        roundOff = 0,
        totalAmount = 0,
        paymentMethod = '',
        amountPaid = 0,
        balanceAmount = 0,
        items = [],
    } = req.body || {};

    if (!Array.isArray(items) || items.length === 0) {
        return res.status(400).json({
            message: 'At least one bill item is required',
        });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const generatedBillNumber =
            billNumber && String(billNumber).trim()
                ? String(billNumber).trim()
                : `BILL - ${Date.now()}`;

        const billResult = await client.query(
            `INSERT INTO billing ( bill_number, customer_id, bill_date, subtotal, discount_amount, gst_amount, round_off, total_amount, payment_method, amount_paid, balance_amount ) VALUES ($1, 3::timestamp, CURRENT_TIMESTAMP),
5, 7, 9, 11) RETURNING bill_id, bill_number`,
            [
                generatedBillNumber,
                customerId || null,
                billDate || null,
                Number(subtotal) || 0,
                Number(discountAmount) || 0,
                Number(gstAmount) || 0,
                Number(roundOff) || 0,
                Number(totalAmount) || 0,
                paymentMethod,
                Number(amountPaid) || 0,
                Number(balanceAmount) || 0,
            ]
        );

        const billId = billResult.rows[0].bill_id;

        for (const item of items) {
            if (!item.itemName || Number(item.quantity) <= 0) {
                throw new Error('Each item needs an itemName and a quantity greater than 0');
            }

            await client.query(
                `INSERT INTO billing_items(bill_id, item_id, item_code, item_name, unit, quantity, rate, discount_amount, gst_percentage, gst_amount, line_total) VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
                [
                    billId,
                    item.itemId || null,
                    item.itemCode || '',
                    item.itemName,
                    item.unit || '',
                    Number(item.quantity),
                    Number(item.rate) || 0,
                    Number(item.discountAmount) || 0,
                    Number(item.gstPercentage) || 0,
                    Number(item.gstAmount) || 0,
                    Number(item.lineTotal) || 0,
                ]
            );
        }

        await client.query('COMMIT');

        return res.status(201).json({
            message: 'Bill saved successfully',
            billId,
            billNumber: billResult.rows[0].bill_number,
        });
    } catch (error) {
        await client.query('ROLLBACK');
        return res.status(500).json({ message: error.message });
    } finally {
        client.release();
    }
}

module.exports = {
    createBill,
};