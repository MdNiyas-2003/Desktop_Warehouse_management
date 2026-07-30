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

  await query(`
    CREATE TABLE IF NOT EXISTS payments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id UUID,
      supplier_id UUID,
      invoice_id UUID,
      payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      payment_method TEXT NOT NULL DEFAULT '',
      reference_no TEXT NOT NULL DEFAULT '',
      cheque_no TEXT NOT NULL DEFAULT '',
      cheque_date TIMESTAMPTZ,
      amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'Paid',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
      CONSTRAINT fk_supplier FOREIGN KEY (supplier_id) REFERENCES supplier_invoices(id)
    )
  `);

  await query(
    "ALTER TABLE payments ADD COLUMN IF NOT EXISTS supplier_id UUID",
  );
  await query(
    "ALTER TABLE payments ADD COLUMN IF NOT EXISTS invoice_id UUID",
  );
  await query(
    "ALTER TABLE payments ADD COLUMN IF NOT EXISTS voucher_no TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE payments ADD COLUMN IF NOT EXISTS cheque_no TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE payments ADD COLUMN IF NOT EXISTS cheque_date TIMESTAMPTZ",
  );

  await query(
    'CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date DESC)',
  );
  await query(
    'CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id)',
  );
  await query(
    'CREATE INDEX IF NOT EXISTS idx_payments_supplier_id ON payments(supplier_id)',
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

///------------------------------------health check Api---------------------------------------///

app.get('/api/health', async (_req, res) => {
  try {
    await query('SELECT 1');
    return res.json({ ok: true, message: 'API and database are healthy' });
  } catch (error) {
    return res.status(500).json({ ok: false, message: error.message });
  }
});
///------------------------------------ Customer Api---------------------------------------///

app.get('/api/customers', async (_req, res) => {
  try {
    const result = await query(
      `SELECT 
     id,
      customer_code,
      company_name,
      short_name,
      customer_category,
      business_type,
      industry,
      business_since,
      website,

      contact_person,
      designation,
      department,
      mobile,
      alternate_mobile,
      office_phone,
      whatsapp,
      email,

      address_line1,
      address_line2,
      area,
      landmark,
      city,
      state,
      country,
      pin_code,
      billing_address,
      shipping_address,

      gst_registration_type,
      gstin,
      pan,
      registration_no,
      msme_no,
      cin_no,
      fssai_no,
      drug_license_no,
      iec_code,

      payment_terms,
      payment_mode,
      currency,
      credit_days,
      credit_limit,
      price_list,
      assigned_salesman,
      sales_region,

      gst_certificate,
      pan_document,
      trade_license,
      address_proof,
      agreement_document,
      other_document,

      notes,
      status,
      created_at,
      updated_at
      FROM customers
      ORDER BY company_name;`,
    );

    return res.json(result.rows);

  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/customers', async (req, res) => {
  const {
    // Company Profile
    customerCode,
    companyName,
    shortName,      // <-- ADD THIS LINE
    customerCategory,
    businessType,
    industry,
    businessSince,
    website,

    // Contact
    contactPerson,
    designation,
    department,
    mobile,
    alternateMobile,
    officePhone,
    whatsapp,
    email,

    // Address
    addressLine1,
    addressLine2,
    area,
    landmark,
    city,
    state,
    country,
    pinCode,
    billingAddress,
    shippingAddress,

    // Business & Tax
    gstRegistrationType,
    gstin,
    pan,
    registrationNo,
    msmeNo,
    cinNo,
    fssaiNo,
    drugLicenseNo,
    iecCode,

    // Finance
    paymentTerms,
    paymentMode,
    currency,
    creditDays,
    creditLimit,
    priceList,
    assignedSalesman,
    salesRegion,

    // Documents
    gstCertificate,
    panDocument,
    tradeLicense,
    addressProof,
    agreementDocument,
    otherDocument,

    // Others
    notes,
    status
  } = req.body;

  if (!companyName || String(companyName).trim().length === 0) {
    return res.status(400).json({ message: 'companyName is required' });
  }

  try {
    const result = await query(
      `INSERT INTO customers (
      customer_code,
      company_name,
      short_name,
      customer_category,
      business_type,
      industry,
      business_since,
      website,

      contact_person,
      designation,
      department,
      mobile,
      alternate_mobile,
      office_phone,
      whatsapp,
      email,

      address_line1,
      address_line2,
      area,
      landmark,
      city,
      state,
      country,
      pin_code,
      billing_address,
      shipping_address,

      gst_registration_type,
      gstin,
      pan,
      registration_no,
      msme_no,
      cin_no,
      fssai_no,
      drug_license_no,
      iec_code,

      payment_terms,
      payment_mode,
      currency,
      credit_days,
      credit_limit,
      price_list,
      assigned_salesman,
      sales_region,

      gst_certificate,
      pan_document,
      trade_license,
      address_proof,
      agreement_document,
      other_document,

      notes,
      status
  )
  VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,
      $9,$10,$11,$12,$13,$14,$15,$16,
      $17,$18,$19,$20,$21,$22,$23,$24,$25,$26,
      $27,$28,$29,$30,$31,$32,$33,$34,$35,
      $36,$37,$38,$39,$40,$41,$42,$43,
      $44,$45,$46,$47,$48,$49,
      $50,$51
  )
  RETURNING *`,
      [
        customerCode,
        companyName,
        shortName,
        customerCategory,
        businessType,
        industry,
        businessSince,
        website,

        contactPerson,
        designation,
        department,
        mobile,
        alternateMobile,
        officePhone,
        whatsapp,
        email,

        addressLine1,
        addressLine2,
        area,
        landmark,
        city,
        state,
        country,
        pinCode,
        billingAddress,
        shippingAddress,

        gstRegistrationType,
        gstin,
        pan,
        registrationNo,
        msmeNo,
        cinNo,
        fssaiNo,
        drugLicenseNo,
        iecCode,

        paymentTerms,
        paymentMode,
        currency,
        creditDays,
        creditLimit,
        priceList,
        assignedSalesman,
        salesRegion,

        gstCertificate,
        panDocument,
        tradeLicense,
        addressProof,
        agreementDocument,
        otherDocument,

        notes,
        status ?? "Active",
      ]
    );

    const row = result.rows[0];

    return res.status(201).json(row);

  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});
app.put('/api/customers/:id', async (req, res) => {
  const { id } = req.params;

  const {
    customerCode,
    companyName,
    shortName,
    customerCategory,
    businessType,
    industry,
    businessSince,
    website,

    contactPerson,
    designation,
    department,
    mobile,
    alternateMobile,
    officePhone,
    whatsapp,
    email,

    addressLine1,
    addressLine2,
    area,
    landmark,
    city,
    state,
    country,
    pinCode,
    billingAddress,
    shippingAddress,

    gstRegistrationType,
    gstin,
    pan,
    registrationNo,
    msmeNo,
    cinNo,
    fssaiNo,
    drugLicenseNo,
    iecCode,

    paymentTerms,
    paymentMode,
    currency,
    creditDays,
    creditLimit,
    priceList,
    assignedSalesman,
    salesRegion,

    gstCertificate,
    panDocument,
    tradeLicense,
    addressProof,
    agreementDocument,
    otherDocument,

    notes,
    status,
  } = req.body;

  try {
    const result = await query(
      `
      UPDATE customers
      SET
        customer_code=$1,
        company_name=$2,
        short_name=$3,
        customer_category=$4,
        business_type=$5,
        industry=$6,
        business_since=$7,
        website=$8,

        contact_person=$9,
        designation=$10,
        department=$11,
        mobile=$12,
        alternate_mobile=$13,
        office_phone=$14,
        whatsapp=$15,
        email=$16,

        address_line1=$17,
        address_line2=$18,
        area=$19,
        landmark=$20,
        city=$21,
        state=$22,
        country=$23,
        pin_code=$24,
        billing_address=$25,
        shipping_address=$26,

        gst_registration_type=$27,
        gstin=$28,
        pan=$29,
        registration_no=$30,
        msme_no=$31,
        cin_no=$32,
        fssai_no=$33,
        drug_license_no=$34,
        iec_code=$35,

        payment_terms=$36,
        payment_mode=$37,
        currency=$38,
        credit_days=$39,
        credit_limit=$40,
        price_list=$41,
        assigned_salesman=$42,
        sales_region=$43,

        gst_certificate=$44,
        pan_document=$45,
        trade_license=$46,
        address_proof=$47,
        agreement_document=$48,
        other_document=$49,

        notes=$50,
        status=$51,
        updated_at=NOW()

      WHERE id=$52

      RETURNING *
      `,
      [
        customerCode,
        companyName,
        shortName,
        customerCategory,
        businessType,
        industry,
        businessSince,
        website,

        contactPerson,
        designation,
        department,
        mobile,
        alternateMobile,
        officePhone,
        whatsapp,
        email,

        addressLine1,
        addressLine2,
        area,
        landmark,
        city,
        state,
        country,
        pinCode,
        billingAddress,
        shippingAddress,

        gstRegistrationType,
        gstin,
        pan,
        registrationNo,
        msmeNo,
        cinNo,
        fssaiNo,
        drugLicenseNo,
        iecCode,

        paymentTerms,
        paymentMode,
        currency,
        creditDays,
        creditLimit,
        priceList,
        assignedSalesman,
        salesRegion,

        gstCertificate,
        panDocument,
        tradeLicense,
        addressProof,
        agreementDocument,
        otherDocument,

        notes,
        status,
        id,
      ],
    );

    if (result.rowCount == 0) {
      return res.status(404).json({
        message: 'Customer not found',
      });
    }

    return res.json(result.rows[0]);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.delete('/api/customers/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await query(
      `DELETE FROM customers
       WHERE id = $1
       RETURNING id`,
      [id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        message: 'Customer not found',
      });
    }

    return res.json({
      message: 'Customer deleted successfully',
    });
  } catch (error) {
    if (error.code === '23503') {
      return res.status(400).json({
        message:
          'This customer already has orders. Delete is not allowed.',
      });
    }

    return res.status(500).json({
      message: error.message,
    });
  }
});

///------------------------------------Orders Api---------------------------------------///
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

app.delete('/api/orders/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await query(
      `DELETE FROM orders
       WHERE id = $1
       RETURNING id`,
      [id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        message: 'Draft not found',
      });
    }

    return res.json({
      message: 'Draft deleted successfully',
    });
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
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
app.get('/api/orders/customer/:customerId', async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        o.id,
        o.order_code AS invoice_no,
        o.amount,
        o.status,
        o.created_at AS invoice_date
      FROM orders o
      WHERE o.customer_id = $1
      ORDER BY o.created_at DESC
      `,
      [req.params.customerId],
    );

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
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
app.get('/api/categories', async (_req, res) => {
  try {
    const result = await query(`
      SELECT
        id,
        name,
        created_at
      FROM categories
      ORDER BY name
    `);

    return res.json(result.rows);

  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.post('/api/categories', async (req, res) => {
  const { name, description = '' } = req.body;

  if (!name || String(name).trim().length === 0) {
    return res.status(400).json({
      message: 'Category name is required',
    });
  }

  try {
    const exists = await query(
      `SELECT id
       FROM categories
       WHERE LOWER(name)=LOWER($1)`,
      [name.trim()],
    );

    if (exists.rowCount > 0) {
      return res.status(409).json({
        message: 'Category already exists',
      });
    }

    const result = await query(
      `INSERT INTO categories
      (name)
      VALUES($1)
      RETURNING *`,
      [
        name.trim(),
      ],
    );

    return res.status(201).json(result.rows[0]);

  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.delete('/api/categories/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await query(
      `DELETE FROM categories
       WHERE id=$1
       RETURNING id`,
      [id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        message: 'Category not found',
      });
    }

    return res.json({
      message: 'Category deleted successfully',
    });

  } catch (error) {

    if (error.code === '23503') {
      return res.status(400).json({
        message:
          'Category already used by items.',
      });
    }

    return res.status(500).json({
      message: error.message,
    });
  }
});
app.get('/api/items', async (req, res) => {
  const { categoryId } = req.query;

  try {

    let result;

    if (categoryId) {

      result = await query(
        `SELECT *
         FROM items
         WHERE category_id=$1
         ORDER BY item_name`,
        [categoryId],
      );

    } else {

      result = await query(
        `SELECT *
         FROM items
         ORDER BY item_name`,
      );
    }

    return res.json(result.rows);

  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.post('/api/items', async (req, res) => {

  const {
  categoryId,
  itemName,
  itemCode,
  unit,
  rate,
  gst,
  stock = 0,
} = req.body;

  if (!itemName) {
    return res.status(400).json({
      message: 'Item name required',
    });
  }

  try {

  const exists = await query(
  `SELECT *
   FROM items
   WHERE category_id = $1
   AND LOWER(item_name) = LOWER($2)`,
  [
    categoryId,
    itemName.trim(),
  ],
);

if (exists.rowCount > 0) {

  const existingItem = exists.rows[0];

  const updated = await query(
    `UPDATE items
     SET stock = stock + $1
     WHERE id = $2
     RETURNING *`,
    [
      req.body.stock ?? 0,
      existingItem.id,
    ],
  );

  return res.status(200).json({
    message: 'Stock updated successfully',
    item: updated.rows[0],
  });
}

    const result = await query(
      `INSERT INTO items
      (
  category_id,
  item_name,
  item_code,
  unit,
  rate,
  gst,
  stock
)
VALUES
($1,$2,$3,$4,$5,$6,$7)
      RETURNING *`,
      [
        categoryId,
        itemName.trim(),
        itemCode,
        unit,
        rate,
        gst,
        stock,
      ],
    );

    return res.status(201).json(result.rows[0]);

  } catch (error) {
    return res.status(500).json({
      message:error.message,
    });
  }

});
app.put('/api/items/:id', async (req, res) => {

  const { id } = req.params;

  const {
    categoryId,
    itemName,
    itemCode,
    unit,
    rate,
    gst,
  } = req.body;

  try {

    const result = await query(
      `UPDATE items
       SET
         category_id=$1,
         item_name=$2,
         item_code=$3,
         unit=$4,
         rate=$5,
         gst=$6
       WHERE id=$7
       RETURNING *`,
      [
        categoryId,
        itemName,
        itemCode,
        unit,
        rate,
        gst,
        id,
      ],
    );

    return res.json(result.rows[0]);

  } catch(error){
    return res.status(500).json({
      message:error.message,
    });
  }

});
app.delete('/api/items/:id', async (req,res)=>{

  const {id}=req.params;

  try{

    const result=await query(
      `DELETE FROM items
       WHERE id=$1
       RETURNING id`,
      [id],
    );

    if(result.rowCount===0){
      return res.status(404).json({
        message:'Item not found',
      });
    }

    return res.json({
      message:'Item deleted successfully',
    });

  }catch(error){

    return res.status(500).json({
      message:error.message,
    });

  }

});
async function handleWarehouseReceipt(req, res) {
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
// -------------------- Sync Item Master --------------------

      const itemName = String(item.itemName || '').trim();

      const itemExists = await client.query(
        `SELECT id
         FROM items
         WHERE LOWER(item_name) = LOWER($1)`,
        [itemName],
      );

      if (itemExists.rowCount > 0) {
        await client.query(
          `UPDATE items
           SET stock = stock + $1,
               rate = $2,
               gst = $3
           WHERE id = $4`,
          [
            qty,
            rate,
            tax,
            itemExists.rows[0].id,
          ],
        );
      } else {
        const categoryResult = await client.query(
          `SELECT id FROM categories WHERE LOWER(name)=LOWER($1) LIMIT 1`,
          [category],
        );

        const categoryId =
          categoryResult.rowCount > 0 ? categoryResult.rows[0].id : null;
        await client.query(
          `INSERT INTO items
            (
              category_id,
              item_name,
              item_code,
              unit,
              rate,
              gst,
              stock
            )
           VALUES
            ($1,$2,$3,$4,$5,$6,$7)`,
          [
            categoryId,
            itemName,
            itemCode,
            String(item.unit || 'pcs'),
            rate,
            tax,
            qty,
          ],
        );
      }
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
}

app.post('/api/warehouse/receipts', handleWarehouseReceipt);
app.post('/api/warehouse/receipt', handleWarehouseReceipt);

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
app.get('/api/suppliers', async (_req, res) => {
  try {
    const result = await query(`
      SELECT DISTINCT
        supplier_name,
        COALESCE(NULLIF(supplier_contact, ''), supplier_phone) AS supplier_code,
        supplier_phone,
        supplier_gstin,
        supplier_address,
        COALESCE(supplier_address, '') AS supplier_location,
        0.0::numeric AS outstanding_balance
      FROM supplier_invoices
      ORDER BY supplier_name
    `);

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.get('/api/supplier-invoices/:supplierName', async (req, res) => {
  try {
    const result = await query(
      `
      SELECT
        si.id,
        si.invoice_no,
        si.grand_total,
        si.invoice_date,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        GREATEST(si.grand_total - COALESCE(SUM(p.amount), 0), 0) AS remaining_amount
      FROM supplier_invoices si
      LEFT JOIN payments p ON p.supplier_id = si.id
      WHERE si.supplier_name = $1
      GROUP BY si.id
      ORDER BY si.invoice_date DESC
      `,
      [req.params.supplierName],
    );

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.get('/api/payments', async (_req, res) => {
  try {
    const result = await query(`
      SELECT
        p.*,
        COALESCE(c.company_name, s.supplier_name, '') AS party_name,
        COALESCE(o.order_code, s.invoice_no, '') AS invoice_no
      FROM payments p
      LEFT JOIN customers c ON c.id = p.customer_id
      LEFT JOIN supplier_invoices s ON s.id = p.supplier_id
      LEFT JOIN orders o ON o.id = p.invoice_id
      ORDER BY payment_date DESC
    `);

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.post('/api/payments', async (req, res) => {
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
      `
      INSERT INTO payments
      (
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
        status
      )
      VALUES
      ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
      RETURNING *;
      `,
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
    return res.status(500).json({
      message: error.message,
    });
  }
});
app.get('/api/payments/customer/:customerId', async (req, res) => {
  try {
    const result = await query(
      `
      SELECT *
      FROM payments
      WHERE customer_id=$1
      ORDER BY payment_date ASC
      `,
      [req.params.customerId],
    );

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
});
startServer();
