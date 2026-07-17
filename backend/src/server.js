require('dotenv').config();

const cors = require('cors');
const express = require('express');
const { query, pool } = require('./db');

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(cors());
app.use(express.json());

async function ensureOrderDispatchColumns() {
  await query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS transport_name TEXT`);
  await query(
    `ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispatch_assignee TEXT`,
  );
  await query(
    `ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispatch_time TIMESTAMPTZ`,
  );
  await query(
    `ALTER TABLE orders ADD COLUMN IF NOT EXISTS expected_delivery_time TIMESTAMPTZ`,
  );
  await query(
    `ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_time TIMESTAMPTZ`,
  );
}

async function ensureWarehouseTables() {
  await query(`
    CREATE TABLE IF NOT EXISTS supplier_invoices (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      supplier_name TEXT NOT NULL,
      invoice_no TEXT NOT NULL,
      invoice_date DATE,
      invoice_date_raw TEXT NOT NULL DEFAULT '',
      reference_po_no TEXT NOT NULL DEFAULT '',
      bill_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      supplier_contact TEXT NOT NULL DEFAULT '',
      supplier_phone TEXT NOT NULL DEFAULT '',
      supplier_gstin TEXT NOT NULL DEFAULT '',
      supplier_address TEXT NOT NULL DEFAULT '',
      transport_name TEXT NOT NULL DEFAULT '',
      vehicle_no TEXT NOT NULL DEFAULT '',
      sub_total NUMERIC(14,2) NOT NULL DEFAULT 0,
      tax_total NUMERIC(14,2) NOT NULL DEFAULT 0,
      grand_total NUMERIC(14,2) NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'Received',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS supplier_invoice_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      invoice_id UUID NOT NULL REFERENCES supplier_invoices(id) ON DELETE CASCADE,
      category TEXT NOT NULL DEFAULT 'General',
      item_name TEXT NOT NULL,
      item_code TEXT NOT NULL,
      hsn_sac TEXT NOT NULL DEFAULT '',
      qty NUMERIC(14,2) NOT NULL DEFAULT 0,
      unit TEXT NOT NULL DEFAULT 'pcs',
      rate NUMERIC(14,2) NOT NULL DEFAULT 0,
      discount NUMERIC(14,2) NOT NULL DEFAULT 0,
      tax NUMERIC(7,2) NOT NULL DEFAULT 0,
      line_subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
      line_tax NUMERIC(14,2) NOT NULL DEFAULT 0,
      line_total NUMERIC(14,2) NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS inventory_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      item_code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'General',
      hsn_sac TEXT NOT NULL DEFAULT '',
      unit TEXT NOT NULL DEFAULT 'pcs',
      last_purchase_rate NUMERIC(14,2) NOT NULL DEFAULT 0,
      supplier_name TEXT NOT NULL DEFAULT '',
      available_stock NUMERIC(14,2) NOT NULL DEFAULT 0,
      last_invoice_id UUID REFERENCES supplier_invoices(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await query(
    'CREATE INDEX IF NOT EXISTS idx_supplier_invoices_created_at ON supplier_invoices(created_at DESC)',
  );
  await query(
    'CREATE INDEX IF NOT EXISTS idx_supplier_invoice_items_invoice_id ON supplier_invoice_items(invoice_id)',
  );
  await query(
    'CREATE INDEX IF NOT EXISTS idx_inventory_items_item_code ON inventory_items(item_code)',
  );
  await query(
    "ALTER TABLE supplier_invoice_items ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General'",
  );
  await query(
    "ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General'",
  );
}

function parseInvoiceDate(value) {
  if (!value || String(value).trim().length === 0) {
    return null;
  }

  const raw = String(value).trim();
  const isoParsed = new Date(raw);
  if (!Number.isNaN(isoParsed.getTime())) {
    return isoParsed.toISOString().slice(0, 10);
  }

  const datePattern = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
  const match = datePattern.exec(raw);
  if (!match) return null;
  const day = match[1].padStart(2, '0');
  const month = match[2].padStart(2, '0');
  const year = match[3];
  return `${year}-${month}-${day}`;
}

app.get('/api/health', async (_req, res) => {
  try {
    await query('SELECT 1');
    return res.json({ ok: true, message: 'API and database are healthy' });
  } catch (error) {
    return res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/customers', async (_req, res) => {
  try {
    const result = await query(
      `SELECT id, company_name, owner_name, mobile, email, gstin, region, address, created_at
       FROM customers
       ORDER BY created_at DESC`,
    );

    return res.json(
      result.rows.map((row) => ({
        id: row.id,
        companyName: row.company_name,
        ownerName: row.owner_name,
        mobile: row.mobile,
        email: row.email,
        gstin: row.gstin,
        region: row.region,
        address: row.address,
      })),
    );
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/customers', async (req, res) => {
  const {
    companyName,
    ownerName = '',
    mobile = '',
    email = '',
    gstin = '',
    region = '',
    address = '',
  } = req.body || {};

  if (!companyName || String(companyName).trim().length === 0) {
    return res.status(400).json({ message: 'companyName is required' });
  }

  try {
    const result = await query(
      `INSERT INTO customers (company_name, owner_name, mobile, email, gstin, region, address)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, company_name, owner_name, mobile, email, gstin, region, address`,
      [companyName, ownerName, mobile, email, gstin, region, address],
    );

    const row = result.rows[0];
    return res.status(201).json({
      id: row.id,
      companyName: row.company_name,
      ownerName: row.owner_name,
      mobile: row.mobile,
      email: row.email,
      gstin: row.gstin,
      region: row.region,
      address: row.address,
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/catalog', async (_req, res) => {
  try {
    const result = await query(
      `SELECT id, category, item_name, sku, rate
       FROM catalog_items
       ORDER BY category, item_name`,
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
});

app.post('/api/catalog', async (req, res) => {
  const { category = 'General', itemName, sku = '', rate = 0 } = req.body || {};

  if (!itemName || String(itemName).trim().length === 0) {
    return res.status(400).json({ message: 'itemName is required' });
  }

  try {
    const result = await query(
      `INSERT INTO catalog_items (category, item_name, sku, rate)
       VALUES ($1, $2, $3, $4)
       RETURNING id, category, item_name, sku, rate`,
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
});

app.get('/api/orders', async (_req, res) => {
  try {
    await query(
      `UPDATE orders
       SET status = 'Delivered',
           delivered_time = COALESCE(delivered_time, NOW()),
           updated_at = NOW()
       WHERE status = 'In Transit'
         AND expected_delivery_time IS NOT NULL
         AND expected_delivery_time <= NOW()`,
    );

    const result = await query(
      `SELECT o.id,
              o.order_code,
              o.customer_id,
              c.company_name,
              o.salesman_name,
              o.amount,
              o.status,
              o.quantity,
              o.notes,
              o.transport_name,
              o.dispatch_assignee,
              o.dispatch_time,
              o.expected_delivery_time,
              o.delivered_time,
              o.created_at,
              COALESCE(
                json_agg(
                  json_build_object(
                    'name', oi.item_name,
                    'sku', oi.sku,
                    'category', oi.category,
                    'quantity', oi.qty,
                    'unitPrice', oi.rate,
                    'total', oi.line_total
                  )
                ) FILTER (WHERE oi.id IS NOT NULL),
                '[]'::json
              ) AS products
       FROM orders o
       JOIN customers c ON c.id = o.customer_id
       LEFT JOIN order_items oi ON oi.order_id = o.id
       GROUP BY o.id, c.company_name
       ORDER BY o.created_at DESC`,
    );

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
      })),
    );
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});
app.get('/api/orders/drafts', async (_req, res) => {
  try {
    const result = await query(`
      SELECT
        o.id,
        o.order_code,
        c.company_name,
        o.salesman_name,
        o.amount,
        o.quantity,
        o.created_at
      FROM orders o
      JOIN customers c
        ON c.id = o.customer_id
      WHERE o.is_draft = true
      ORDER BY o.created_at DESC
    `);

    return res.json(
      result.rows.map((row) => ({
        id: row.id,
        orderId: row.order_code,
        customerName: row.company_name,
        salesmanName: row.salesman_name,
        amount: Number(row.amount),
        quantity: Number(row.quantity),
        createdAt: row.created_at,
      })),
    );
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.get('/api/orders/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await query(
      `SELECT
          o.id,
          o.order_code,
          o.customer_id,
          c.company_name,
          o.salesman_name,
          o.amount,
          o.quantity,
          o.notes,
          o.status,
          o.is_draft,
          COALESCE(
            json_agg(
              json_build_object(
                'name', oi.item_name,
                'sku', oi.sku,
                'category', oi.category,
                'quantity', oi.qty,
                'unitPrice', oi.rate,
                'total', oi.line_total
              )
            ) FILTER (WHERE oi.id IS NOT NULL),
            '[]'::json
          ) AS products
      FROM orders o
      JOIN customers c
        ON c.id = o.customer_id
      LEFT JOIN order_items oi
        ON oi.order_id = o.id
      WHERE o.id = $1
      GROUP BY
        o.id,
        c.company_name`,
      [id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        message: 'Draft not found',
      });
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
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.post('/api/orders', async (req, res) => {
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
    return res.status(400).json({ message: 'shopId or shopName is required' });
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
        `INSERT INTO customers (company_name)
         VALUES ($1)
         RETURNING id`,
        [shopName],
      );
      customerId = customerResult.rows[0].id;
    }

    const orderResult = await client.query(
      `INSERT INTO orders (order_code, customer_id, salesman_name, amount, status, is_draft, quantity, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, order_code`,
      [
        clientOrderCode,
        customerId,
        salesmanName,
        Number(amount) || 0,
        status,
        isDraft,
        Number(quantity) || 0,
        notes,
      ],
    );

    const orderDbId = orderResult.rows[0].id;

    for (const product of products) {
      await client.query(
        `INSERT INTO order_items (order_id, category, item_name, sku, qty, rate, line_total)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          orderDbId,
          product.category || 'General',
          product.name || product.itemName || 'Item',
          product.sku || 'SKU',
          Number(product.quantity) || 0,
          Number(product.unitPrice || product.rate) || 0,
          Number(product.total) || 0,
        ],
      );
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
});

app.patch('/api/orders/:id/status', async (req, res) => {
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
      `UPDATE orders
       SET status = $1,
           transport_name = COALESCE($3, transport_name),
           dispatch_assignee = COALESCE($4, dispatch_assignee),
           dispatch_time = COALESCE($5::timestamptz, dispatch_time),
           expected_delivery_time = COALESCE(
             $6::timestamptz,
             CASE
               WHEN $1 = 'In Transit' THEN COALESCE($5::timestamptz, dispatch_time) + INTERVAL '1 day'
               ELSE expected_delivery_time
             END
           ),
           delivered_time = COALESCE($7::timestamptz, delivered_time),
           updated_at = NOW()
       WHERE id::text = $2 OR order_code = $2
       RETURNING id`,
      [
        status,
        id,
        transportName,
        dispatchAssignee,
        dispatchTime,
        expectedDeliveryTime,
        deliveredTime,
      ],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Order not found' });
    }

    return res.json({ ok: true });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/warehouse/receipts', async (req, res) => {
  const {
    supplier,
    invoiceNo,
    invoiceDate,
    referencePoNo = '',
    billAmount = 0,
    taxAmount = 0,
    notes = '',
    supplierContact = '',
    supplierPhone = '',
    supplierGstin = '',
    supplierAddress = '',
    transportName = '',
    vehicleNo = '',
    subTotal = 0,
    taxTotal = 0,
    grandTotal = 0,
    status = 'Received',
    items = [],
  } = req.body || {};

  if (!supplier || String(supplier).trim().length === 0) {
    return res.status(400).json({ message: 'supplier is required' });
  }

  if (!invoiceNo || String(invoiceNo).trim().length === 0) {
    return res.status(400).json({ message: 'invoiceNo is required' });
  }

  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ message: 'At least one item is required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const parsedInvoiceDate = parseInvoiceDate(invoiceDate);
    const invoiceResult = await client.query(
      `INSERT INTO supplier_invoices (
          supplier_name,
          invoice_no,
          invoice_date,
          invoice_date_raw,
          reference_po_no,
          bill_amount,
          tax_amount,
          notes,
          supplier_contact,
          supplier_phone,
          supplier_gstin,
          supplier_address,
          transport_name,
          vehicle_no,
          sub_total,
          tax_total,
          grand_total,
          status
       ) VALUES (
          $1, $2, $3::date, $4, $5, $6, $7, $8, $9, $10,
          $11, $12, $13, $14, $15, $16, $17, $18
       )
       RETURNING id`,
      [
        String(supplier).trim(),
        String(invoiceNo).trim(),
        parsedInvoiceDate,
        String(invoiceDate || '').trim(),
        String(referencePoNo || '').trim(),
        Number(billAmount) || 0,
        Number(taxAmount) || 0,
        String(notes || '').trim(),
        String(supplierContact || '').trim(),
        String(supplierPhone || '').trim(),
        String(supplierGstin || '').trim(),
        String(supplierAddress || '').trim(),
        String(transportName || '').trim(),
        String(vehicleNo || '').trim(),
        Number(subTotal) || 0,
        Number(taxTotal) || 0,
        Number(grandTotal) || 0,
        String(status || 'Received').trim() || 'Received',
      ],
    );

    const invoiceId = invoiceResult.rows[0].id;
    let totalQuantity = 0;

    for (const item of items) {
      const category =
        String(item.category || 'Ready Mades').trim() || 'Ready Mades';
      const qty = Number(item.qty ?? item.quantity) || 0;
      if (qty <= 0) {
        throw new Error('Each item must have quantity greater than 0');
      }

      const rate = Number(item.rate) || 0;
      const discount = Number(item.discount) || 0;
      const tax = Number(item.tax) || 0;
      const lineSubTotal = Math.max((qty * rate) - discount, 0);
      const lineTax = lineSubTotal * (tax / 100);
      const lineTotal = lineSubTotal + lineTax;

      const itemCodeRaw = String(item.itemCode || item.itemName || 'item')
        .trim()
        .toLowerCase();
      const itemCode = itemCodeRaw
        .replace(/[^a-z0-9_-]+/g, '_')
        .replace(/_+/g, '_');

      await client.query(
        `INSERT INTO supplier_invoice_items (
            invoice_id, category, item_name, item_code, hsn_sac, qty, unit, rate,
            discount, tax, line_subtotal, line_tax, line_total
         ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8,
            $9, $10, $11, $12, $13
         )`,
        [
          invoiceId,
          category,
          String(item.itemName || 'Item').trim(),
          itemCode || 'item',
          String(item.hsnSac || '').trim(),
          qty,
          String(item.unit || 'pcs').trim() || 'pcs',
          rate,
          discount,
          tax,
          lineSubTotal,
          lineTax,
          lineTotal,
        ],
      );

      await client.query(
        `INSERT INTO inventory_items (
            item_code,
            name,
            category,
            hsn_sac,
            unit,
            last_purchase_rate,
            supplier_name,
            available_stock,
            last_invoice_id
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (item_code)
         DO UPDATE SET
            name = EXCLUDED.name,
            category = EXCLUDED.category,
            hsn_sac = EXCLUDED.hsn_sac,
            unit = EXCLUDED.unit,
            last_purchase_rate = EXCLUDED.last_purchase_rate,
            supplier_name = EXCLUDED.supplier_name,
            available_stock = inventory_items.available_stock + EXCLUDED.available_stock,
            last_invoice_id = EXCLUDED.last_invoice_id,
            updated_at = NOW()`,
        [
          itemCode || 'item',
          String(item.itemName || 'Item').trim(),
          category,
          String(item.hsnSac || '').trim(),
          String(item.unit || 'pcs').trim() || 'pcs',
          rate,
          String(supplier).trim(),
          qty,
          invoiceId,
        ],
      );

      // Keep item master in sync with warehouse inward receipts.
      const catalogUpdate = await client.query(
        `UPDATE catalog_items
         SET item_name = $1,
             sku = $2,
             rate = $3,
             category = $4,
             updated_at = NOW()
         WHERE LOWER(sku) = LOWER($2) OR LOWER(item_name) = LOWER($1)`,
        [
          String(item.itemName || 'Item').trim(),
          itemCode || 'item',
          rate,
          category,
        ],
      );

      if (catalogUpdate.rowCount === 0) {
        await client.query(
          `INSERT INTO catalog_items (category, item_name, sku, rate)
           VALUES ($1, $2, $3, $4)`,
          [
            category,
            String(item.itemName || 'Item').trim(),
            itemCode || 'item',
            rate,
          ],
        );
      }

      totalQuantity += qty;
    }

    await client.query('COMMIT');
    return res.status(201).json({
      id: invoiceId,
      invoiceNo: String(invoiceNo).trim(),
      supplier: String(supplier).trim(),
      quantity: totalQuantity,
      itemsCount: items.length,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    return res.status(500).json({ message: error.message });
  } finally {
    client.release();
  }
});

async function startServer() {
  try {
    await ensureOrderDispatchColumns();
    await ensureWarehouseTables();
    app.listen(port, () => {
      console.log(`Sales ERP API running on http://localhost:${port}`);
    });
  } catch (error) {
    console.error('Failed to initialize database schema:', error.message);
    process.exit(1);
  }
}

startServer();
