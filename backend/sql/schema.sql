CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  owner_name TEXT NOT NULL DEFAULT '',
  mobile TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  gstin TEXT NOT NULL DEFAULT '',
  region TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL DEFAULT 'General',
  item_name TEXT NOT NULL,
  sku TEXT NOT NULL,
  rate NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code TEXT NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  salesman_name TEXT NOT NULL,
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'Pending',
  quantity NUMERIC(14,2) NOT NULL DEFAULT 0,
  notes TEXT NOT NULL DEFAULT '',
  transport_name TEXT,
  dispatch_assignee TEXT,
  dispatch_time TIMESTAMPTZ,
  expected_delivery_time TIMESTAMPTZ,
  delivered_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'General',
  item_name TEXT NOT NULL,
  sku TEXT NOT NULL,
  qty NUMERIC(14,2) NOT NULL DEFAULT 0,
  rate NUMERIC(14,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS transport_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispatch_assignee TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispatch_time TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS expected_delivery_time TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_time TIMESTAMPTZ;

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
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_normalized_name
  ON suppliers (LOWER(BTRIM(supplier_name)));

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
);

ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES suppliers(id);
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS delivery_note TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS receiving_date DATE;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS received_by TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS freight NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS other_charges NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS round_off NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS balance_amount NUMERIC(14,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS payment_terms TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS payment_mode TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS reference_number TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS warehouse_name TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS rack_bin TEXT NOT NULL DEFAULT '';
ALTER TABLE supplier_invoices
  ADD COLUMN IF NOT EXISTS receiving_location TEXT NOT NULL DEFAULT '';

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
ON CONFLICT DO NOTHING;

UPDATE supplier_invoices si
SET supplier_id = s.id
FROM suppliers s
WHERE si.supplier_id IS NULL
  AND LOWER(BTRIM(si.supplier_name)) = LOWER(BTRIM(s.supplier_name));

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
);

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
);

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_created_at
  ON supplier_invoices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_supplier_invoice_items_invoice_id
  ON supplier_invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_item_code
  ON inventory_items(item_code);

ALTER TABLE supplier_invoice_items
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General';
ALTER TABLE inventory_items
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General';

ALTER TABLE items
  ADD COLUMN IF NOT EXISTS item_code TEXT NOT NULL DEFAULT '';

CREATE SEQUENCE IF NOT EXISTS items_item_code_seq;

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
FROM existing_codes, sequence_state;

UPDATE items
SET item_code = 'ITEM-' || LPAD(nextval('items_item_code_seq')::TEXT, 6, '0')
WHERE item_code IS NULL OR BTRIM(item_code) = '';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM items
    WHERE BTRIM(item_code) <> ''
    GROUP BY UPPER(BTRIM(item_code))
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Duplicate item codes exist. Resolve them before creating the unique item-code index.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_items_item_code_unique
  ON items (UPPER(BTRIM(item_code)));
