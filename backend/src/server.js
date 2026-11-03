require('dotenv').config();

const cors = require('cors');
const express = require('express');
const { query } = require('./db');

const healthRoutes = require('./routes/healthRoutes');
const customerRoutes = require('./routes/customerRoutes');
const orderRoutes = require('./routes/orderRoutes');
const catalogRoutes = require('./routes/catalogRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const itemRoutes = require('./routes/itemRoutes');
const warehouseRoutes = require('./routes/warehouseRoutes');
const supplierRoutes = require('./routes/supplierRoutes');
const supplierInvoiceRoutes = require('./routes/supplierInvoiceRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const billingRoutes = require('./routes/billingRoutes');


const app = express();
const port = Number(process.env.PORT || 4000);

app.use(cors());
app.use(express.json());

// Keep these two functions from your old server.js unchanged:
// async function ensureOrderDispatchColumns() { ... }
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
// async function ensureWarehouseTables() { ... }
async function ensureWarehouseTables() {
  await query(`
    CREATE TABLE IF NOT EXISTS suppliers (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      supplier_name TEXT NOT NULL,
      supplier_code TEXT NOT NULL DEFAULT '',
      supplier_contact TEXT NOT NULL DEFAULT '',
      supplier_phone TEXT NOT NULL DEFAULT '',
      supplier_gstin TEXT NOT NULL DEFAULT '',
      supplier_address TEXT NOT NULL DEFAULT '',
      supplier_location TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await query(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_normalized_name ON suppliers (LOWER(BTRIM(supplier_name)))',
  );

  await query(`
    CREATE TABLE IF NOT EXISTS supplier_invoices (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      supplier_id UUID REFERENCES suppliers(id),
      supplier_name TEXT NOT NULL,
      invoice_no TEXT NOT NULL,
      invoice_date DATE,
      invoice_date_raw TEXT NOT NULL DEFAULT '',
      delivery_note TEXT NOT NULL DEFAULT '',
      receiving_date DATE,
      received_by TEXT NOT NULL DEFAULT '',
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
      discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      freight NUMERIC(14,2) NOT NULL DEFAULT 0,
      other_charges NUMERIC(14,2) NOT NULL DEFAULT 0,
      round_off NUMERIC(14,2) NOT NULL DEFAULT 0,
      paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      balance_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      payment_terms TEXT NOT NULL DEFAULT '',
      payment_mode TEXT NOT NULL DEFAULT '',
      due_date DATE,
      reference_number TEXT NOT NULL DEFAULT '',
      warehouse_name TEXT NOT NULL DEFAULT '',
      rack_bin TEXT NOT NULL DEFAULT '',
      receiving_location TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'Received',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES suppliers(id)',
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS delivery_note TEXT NOT NULL DEFAULT ''",
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS receiving_date DATE',
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS received_by TEXT NOT NULL DEFAULT ''",
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS freight NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS other_charges NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS round_off NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS balance_amount NUMERIC(14,2) NOT NULL DEFAULT 0',
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS payment_terms TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS payment_mode TEXT NOT NULL DEFAULT ''",
  );
  await query(
    'ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS due_date DATE',
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS reference_number TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS warehouse_name TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS rack_bin TEXT NOT NULL DEFAULT ''",
  );
  await query(
    "ALTER TABLE supplier_invoices ADD COLUMN IF NOT EXISTS receiving_location TEXT NOT NULL DEFAULT ''",
  );
  await query(`
    INSERT INTO suppliers (
      supplier_name, supplier_code, supplier_contact, supplier_phone,
      supplier_gstin, supplier_address, supplier_location
    )
    SELECT DISTINCT ON (LOWER(BTRIM(supplier_name)))
      BTRIM(supplier_name),
      supplier_contact,
      supplier_contact,
      supplier_phone,
      supplier_gstin,
      supplier_address,
      supplier_address
    FROM supplier_invoices
    WHERE BTRIM(supplier_name) <> ''
    ORDER BY LOWER(BTRIM(supplier_name)), updated_at DESC
    ON CONFLICT DO NOTHING
  `);
  await query(`
    UPDATE supplier_invoices si
    SET supplier_id = s.id
    FROM suppliers s
    WHERE si.supplier_id IS NULL
      AND LOWER(BTRIM(si.supplier_name)) = LOWER(BTRIM(s.supplier_name))
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

async function ensureItemCodeSequence() {
  await query(
    "ALTER TABLE items ADD COLUMN IF NOT EXISTS item_code TEXT NOT NULL DEFAULT ''",
  );
  await query('CREATE SEQUENCE IF NOT EXISTS items_item_code_seq');
  await query(`
    WITH existing_codes AS (
      SELECT COALESCE(
        MAX(SUBSTRING(item_code FROM 6)::BIGINT),
        0
      ) AS max_code
      FROM items
      WHERE item_code ~* '^ITEM-[0-9]+$'
    ),
    sequence_state AS (
      SELECT last_value, is_called FROM items_item_code_seq
    )
    SELECT CASE
      WHEN sequence_state.is_called THEN sequence_state.last_value
      ELSE setval(
        'items_item_code_seq',
        GREATEST(existing_codes.max_code, 1),
        existing_codes.max_code > 0
      )
    END
    FROM existing_codes, sequence_state
  `);
  await query(`
    UPDATE items
    SET item_code = 'ITEM-' || LPAD(nextval('items_item_code_seq')::TEXT, 6, '0')
    WHERE item_code IS NULL OR BTRIM(item_code) = ''
  `);

  const duplicates = await query(`
    SELECT UPPER(BTRIM(item_code)) AS item_code, COUNT(*) AS count
    FROM items
    WHERE BTRIM(item_code) <> ''
    GROUP BY UPPER(BTRIM(item_code))
    HAVING COUNT(*) > 1
    LIMIT 1
  `);
  if (duplicates.rowCount > 0) {
    throw new Error(
      `Duplicate item code "${duplicates.rows[0].item_code}" exists. Resolve duplicate item codes before startup.`,
    );
  }
  await query(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_items_item_code_unique ON items (UPPER(BTRIM(item_code)))',
  );
}

// API routes
app.use('/api/health', healthRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/items', itemRoutes);
app.use('/api/warehouse', warehouseRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/supplier-invoices', supplierInvoiceRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/billing',billingRoutes);

async function startServer() {
try {
await ensureOrderDispatchColumns();
await ensureWarehouseTables();
await ensureItemCodeSequence();

app.listen(port, () => {
console.log(`Sales ERP API running on http://localhost:${port}`);
});
} catch (error) {
console.error('Failed to initialize database schema:', error.message);
process.exit(1);
}
}

startServer();