
const { query, pool } = require('../db');

async function getOrders(_req, res) {
    try {
        // Mark overdue in-transit orders as delivered.
        await query(`UPDATE orders SET status = 'Delivered', delivered_time = COALESCE(delivered_time, NOW()), updated_at = NOW() WHERE status = 'In Transit' AND expected_delivery_time IS NOT NULL AND expected_delivery_time <= NOW()`);

        const result = await query(`SELECT o.id, o.order_code, o.customer_id, c.company_name, o.salesman_name, o.amount, o.status, o.quantity, o.notes, o.transport_name, o.dispatch_assignee, o.dispatch_time, o.expected_delivery_time, o.delivered_time, o.created_at, COALESCE( json_agg( json_build_object( 'name', oi.item_name, 'sku', oi.sku, 'category', oi.category, 'quantity', oi.qty, 'unitPrice', oi.rate, 'total', oi.line_total ) ) FILTER (WHERE oi.id IS NOT NULL), '[]'::json ) AS products FROM orders o JOIN customers c ON c.id = o.customer_id LEFT JOIN order_items oi ON oi.order_id = o.id GROUP BY o.id, c.company_name ORDER BY o.created_at DESC`);

        return res.json(
            result.rows.map((row) => ({
                id: row.id,
                orderId: row.order_code,
                shopId: row.customer_id,
                shopName: row.company_name,
                salesmanName: row.salesman_name,
                amount: Number(row.amount),
                total: Number(row.amount),
                status: row.status,
                quantity: Number(row.quantity),
                notes: row.notes || '',
                transportName: row.transport_name || 'Not Assigned',
                dispatchAssignee: row.dispatch_assignee || 'Not assigned',
                dispatchTime: row.dispatch_time,
                expectedDeliveryTime: row.expected_delivery_time,
                deliveredTime: row.delivered_time,
                productsCount: Array.isArray(row.products) ? row.products.length : 0,
                products: row.products || [],
                createdAt: row.created_at,
                customer: {
                    companyName: row.company_name,
                },
            }))
        );
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function deleteOrder(req, res) {
    const { id } = req.params;

    try {
        const result = await query(
            `DELETE FROM orders WHERE id = $1
RETURNING id`,
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Draft not found' });
        }

        return res.json({ message: 'Draft deleted successfully' });
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function getOrderDrafts(_req, res) {
    try {
        const result = await query(`SELECT o.id, o.order_code, c.company_name, o.salesman_name, o.amount, o.quantity, o.created_at FROM orders o JOIN customers c ON c.id = o.customer_id WHERE o.is_draft = true ORDER BY o.created_at DESC`);

        return res.json(
            result.rows.map((row) => ({
                id: row.id,
                orderId: row.order_code,
                customerName: row.company_name,
                salesmanName: row.salesman_name,
                amount: Number(row.amount),
                quantity: Number(row.quantity),
                createdAt: row.created_at,
            }))
        );
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function getOrderById(req, res) {
    const { id } = req.params;

    try {
        const result = await query(
            `SELECT o.id, o.order_code, o.customer_id, c.company_name, o.salesman_name, o.amount, o.quantity, o.notes, o.status, o.is_draft, COALESCE( json_agg( json_build_object( 'name', oi.item_name, 'sku', oi.sku, 'category', oi.category, 'quantity', oi.qty, 'unitPrice', oi.rate, 'total', oi.line_total ) ) FILTER (WHERE oi.id IS NOT NULL), '[]'::json ) AS products FROM orders o JOIN customers c ON c.id = o.customer_id LEFT JOIN order_items oi ON oi.order_id = o.id WHERE o.id =$1
GROUP BY o.id, c.company_name`,
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Draft not found' });
        }

        const row = result.rows[0];

        return res.json({
            id: row.id,
            orderId: row.order_code,
            shopId: row.customer_id,
            shopName: row.company_name,
            salesmanName: row.salesman_name,
            amount: Number(row.amount),
            quantity: Number(row.quantity),
            notes: row.notes,
            status: row.status,
            isDraft: row.is_draft,
            products: row.products ?? [],
        });
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function createOrder(req, res) {
    const {
        orderId,
        shopId,
        shopName,
        salesmanName,
        amount = 0,
        quantity = 0,
        notes = '',
        status = 'Pending',
        isDraft = false,
        products = [],
    } = req.body || {};

    if (!shopId && !shopName) {
        return res.status(400).json({
            message: 'shopId or shopName is required',
        });
    }

    if (!salesmanName || String(salesmanName).trim().length === 0) {
        return res.status(400).json({ message: 'salesmanName is required' });
    }

    const clientOrderCode =
        orderId && String(orderId).trim().length > 0
            ? String(orderId)
            : `ORD-${Date.now()}`;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        let customerId = shopId;

        if (!customerId) {
            const customerResult = await client.query(
                `INSERT INTO customers (company_name) VALUES ($1)
RETURNING id`,
                [shopName]
            );

            customerId = customerResult.rows[0].id;
        }

        const orderResult = await client.query(
            `INSERT INTO orders ( order_code, customer_id, salesman_name, amount, status, is_draft, quantity, notes ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id, order_code,
[
clientOrderCode,
customerId,
salesmanName,
Number(amount) || 0,
status,
isDraft,
Number(quantity) || 0,
notes,
 ]`
        );

        const orderDbId = orderResult.rows[0].id;

        for (const product of products) {
            await client.query(
                `INSERT INTO order_items ( order_id, category, item_name, sku, qty, rate, line_total ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                [
                    orderDbId,
                    product.category || 'General',
                    product.name || product.itemName || 'Item',
                    product.sku || 'SKU',
                    Number(product.quantity) || 0,
                    Number(product.unitPrice || product.rate) || 0,
                    Number(product.total) || 0,
                ]
            ); ``
        }

        await client.query('COMMIT');

        return res.status(201).json({
            id: orderDbId,
            orderId: orderResult.rows[0].order_code,
        });
    } catch (error) {
        await client.query('ROLLBACK');
        return res.status(500).json({ message: error.message });
    } finally {
        client.release();
    }
}

async function getCustomerOrders(req, res) {
    try {
        const result = await query(
            `SELECT o.id, o.order_code AS invoice_no, o.amount, o.status, o.created_at AS invoice_date FROM orders o WHERE o.customer_id =$1 ORDER BY o.created_at DESC`,
            [req.params.customerId]
        );

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function updateOrderStatus(req, res) {
    const { id } = req.params;

    const {
        status,
        transportName = null,
        dispatchAssignee = null,
        dispatchTime = null,
        expectedDeliveryTime = null,
        deliveredTime = null,
    } = req.body || {};

    if (!status || String(status).trim().length === 0) {
        return res.status(400).json({ message: 'status is required' });
    }

    try {
        const result = await query(
            `UPDATE orders SET status = $1,
transport_name = COALESCE($3, transport_name), dispatch_assignee = COALESCE($4, dispatch_assignee),
dispatch_time = COALESCE($5::timestamptz, dispatch_time), expected_delivery_time = COALESCE( $6::timestamptz,
CASE
WHEN $1 = 'In Transit' THEN COALESCE($5::timestamptz, dispatch_time) + INTERVAL '1 day'
ELSE expected_delivery_time
END
),
delivered_time = COALESCE($7::timestamptz, delivered_time), updated_at = NOW() WHERE id::text = $2 OR order_code = $2 RETURNING id`,
            [
                status,
                id,
                transportName,
                dispatchAssignee,
                dispatchTime,
                expectedDeliveryTime,
                deliveredTime,
            ]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Order not found' });
        }

        return res.json({ ok: true });
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

module.exports = {
    getOrders,
    deleteOrder,
    getOrderDrafts,
    getOrderById,
    createOrder,
    getCustomerOrders,
    updateOrderStatus,
};