const { pool } = require('../db');

function parseReceiptDate(value, fieldName) {
  if (!value || String(value).trim() === '') return null;

  const raw = String(value).trim();
  let year;
  let month;
  let day;
  const displayDate = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(raw);
  if (displayDate) {
    day = Number(displayDate[1]);
    month = Number(displayDate[2]);
    year = Number(displayDate[3]);
  } else {
    const isoDate = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
    if (!isoDate) throw new Error(`${fieldName} must be a valid date`);
    year = Number(isoDate[1]);
    month = Number(isoDate[2]);
    day = Number(isoDate[3]);
  }

  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new Error(`${fieldName} must be a valid date`);
  }
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function numberValue(value, fieldName, fallback = 0) {
  if (value == null || value === '') return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) throw new Error(`${fieldName} must be a number`);
  return parsed;
}

async function findOrCreateSupplier(client, body) {
  const name = String(body.supplier || '').trim();
  if (body.supplierId) {
    const selected = await client.query(
      'SELECT * FROM suppliers WHERE id = $1 FOR SHARE',
      [body.supplierId],
    );
    if (selected.rowCount === 0) {
      const error = new Error('Selected supplier was not found');
      error.statusCode = 400;
      throw error;
    }
    return selected.rows[0];
  }

  let result = await client.query(
    `SELECT * FROM suppliers
     WHERE LOWER(BTRIM(supplier_name)) = LOWER(BTRIM($1))
     LIMIT 1 FOR SHARE`,
    [name],
  );
  if (result.rowCount > 0) return result.rows[0];

  result = await client.query(
    `INSERT INTO suppliers (
       supplier_name, supplier_code, supplier_contact, supplier_phone,
       supplier_gstin, supplier_address, supplier_location
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT DO NOTHING
     RETURNING *`,
    [
      name,
      String(body.supplierCode || '').trim(),
      String(body.supplierContact || '').trim(),
      String(body.supplierPhone || '').trim(),
      String(body.supplierGstin || '').trim(),
      String(body.supplierAddress || '').trim(),
      String(body.supplierLocation || '').trim(),
    ],
  );
  if (result.rowCount > 0) return result.rows[0];

  result = await client.query(
    `SELECT * FROM suppliers
     WHERE LOWER(BTRIM(supplier_name)) = LOWER(BTRIM($1))
     LIMIT 1 FOR SHARE`,
    [name],
  );
  return result.rows[0];
}

async function handleWarehouseReceipt(req, res) {
  const body = req.body || {};
  const supplierName = String(body.supplier || '').trim();
  const invoiceNo = String(body.invoiceNo || '').trim();
  const items = body.items;

  if (!supplierName) {
    return res.status(400).json({ message: 'Supplier is required' });
  }
  if (!invoiceNo) {
    return res.status(400).json({ message: 'Invoice number is required' });
  }
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ message: 'At least one item is required' });
  }

  let invoiceDate;
  let receivingDate;
  let dueDate;
  let normalizedItems;
  let financial;
  try {
    invoiceDate = parseReceiptDate(body.invoiceDate, 'Invoice date');
    receivingDate = parseReceiptDate(body.receivingDate, 'Receiving date');
    dueDate = parseReceiptDate(body.dueDate, 'Due date');

    normalizedItems = items.map((item, index) => {
      const itemName = String(item.itemName || '').trim();
      const category = String(item.category || '').trim();
      const itemCode = String(item.itemCode || itemName)
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9_-]+/g, '_')
        .replace(/_+/g, '_');
      const qty = numberValue(item.qty ?? item.quantity, `Item ${index + 1} quantity`);
      const rate = numberValue(item.rate, `Item ${index + 1} rate`);
      const discount = numberValue(item.discount, `Item ${index + 1} discount`);
      const tax = numberValue(item.tax, `Item ${index + 1} GST`);

      if (!itemName || !category || !itemCode || !String(item.unit || '').trim()) {
        throw new Error(`Item ${index + 1} requires a name, category, code, and unit`);
      }
      if (qty <= 0 || rate < 0 || discount < 0 || tax < 0) {
        throw new Error(`Item ${index + 1} has invalid quantity or amount values`);
      }
      return {
        ...item,
        itemId: item.itemId == null ? null : Number(item.itemId),
        itemName,
        category,
        itemCode,
        unit: String(item.unit).trim(),
        qty,
        rate,
        discount,
        tax,
        lineSubTotal: Math.max(qty * rate - discount, 0),
      };
    });

    financial = {
      subTotal: normalizedItems.reduce((sum, item) => sum + item.lineSubTotal, 0),
      taxTotal: normalizedItems.reduce(
        (sum, item) => sum + item.lineSubTotal * (item.tax / 100),
        0,
      ),
      discountAmount: numberValue(body.discountAmount, 'Discount'),
      freight: numberValue(body.freight, 'Freight'),
      otherCharges: numberValue(body.otherCharges, 'Other charges'),
      roundOff: numberValue(body.roundOff, 'Round off'),
      paidAmount: numberValue(body.paidAmount, 'Paid amount'),
    };
    if (
      financial.discountAmount < 0 ||
      financial.freight < 0 ||
      financial.otherCharges < 0 ||
      financial.paidAmount < 0
    ) {
      throw new Error('Financial amounts cannot be negative');
    }
    financial.taxAmount = financial.taxTotal;
    financial.billAmount = financial.subTotal;
    financial.grandTotal = financial.subTotal + financial.taxTotal;
    financial.balanceAmount = Math.max(
      financial.grandTotal - financial.paidAmount,
      0,
    );
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const supplier = await findOrCreateSupplier(client, {
      ...body,
      supplier: supplierName,
    });
    if (!supplier) {
      throw new Error('Unable to resolve supplier');
    }

    const invoiceResult = await client.query(
      `INSERT INTO supplier_invoices (
          supplier_id, supplier_name, invoice_no, invoice_date, invoice_date_raw,
          delivery_note, receiving_date, received_by, reference_po_no,
          bill_amount, tax_amount, notes, supplier_contact, supplier_phone,
          supplier_gstin, supplier_address, transport_name, vehicle_no,
          sub_total, tax_total, grand_total, discount_amount, freight,
          other_charges, round_off, paid_amount, balance_amount, payment_terms,
          payment_mode, due_date, reference_number, warehouse_name, rack_bin,
          receiving_location, status
       ) VALUES (
          $1, $2, $3, $4::date, $5, $6, $7::date, $8, $9, $10, $11, $12,
          $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24,
          $25, $26, $27, $28, $29, $30::date, $31, $32, $33, $34, $35
       )
       RETURNING id`,
      [
        supplier.id,
        supplier.supplier_name,
        invoiceNo,
        invoiceDate,
        String(body.invoiceDate || '').trim(),
        String(body.deliveryNote || '').trim(),
        receivingDate,
        String(body.receivedBy || '').trim(),
        String(body.referencePoNo || body.poNumber || '').trim(),
        financial.billAmount,
        financial.taxAmount,
        String(body.notes || '').trim(),
        supplier.supplier_contact,
        supplier.supplier_phone,
        supplier.supplier_gstin,
        supplier.supplier_address,
        String(body.transportName || '').trim(),
        String(body.vehicleNo || '').trim(),
        financial.subTotal,
        financial.taxTotal,
        financial.grandTotal,
        financial.discountAmount,
        financial.freight,
        financial.otherCharges,
        financial.roundOff,
        financial.paidAmount,
        financial.balanceAmount,
        String(body.paymentTerms || '').trim(),
        String(body.paymentMode || '').trim(),
        dueDate,
        String(body.referenceNumber || '').trim(),
        String(body.warehouseName || '').trim(),
        String(body.rackBin || '').trim(),
        String(body.receivingLocation || '').trim(),
        String(body.status || 'Received').trim() || 'Received',
      ],
    );

    const invoiceId = invoiceResult.rows[0].id;
    const totalQuantity = normalizedItems.reduce((sum, item) => sum + item.qty, 0);

    for (const item of normalizedItems) {
      let masterItem;
      if (Number.isInteger(item.itemId) && item.itemId > 0) {
        masterItem = await client.query(
          'SELECT id, item_code FROM items WHERE id = $1 FOR UPDATE',
          [item.itemId],
        );
      } else {
        masterItem = await client.query(
          `SELECT id, item_code FROM items
           WHERE LOWER(BTRIM(item_name)) = LOWER(BTRIM($1))
           LIMIT 1 FOR UPDATE`,
          [item.itemName],
        );
      }

      if (masterItem.rowCount > 0) {
        item.itemCode = masterItem.rows[0].item_code;
        await client.query(
          `UPDATE items
           SET stock = stock + $1, rate = $2, gst = $3
           WHERE id = $4`,
          [item.qty, item.rate, item.tax, masterItem.rows[0].id],
        );
      } else {
        const categoryResult = await client.query(
          'SELECT id FROM categories WHERE LOWER(BTRIM(name)) = LOWER(BTRIM($1)) LIMIT 1',
          [item.category],
        );
        const insertedItem = await client.query(
          `INSERT INTO items
            (category_id, item_name, item_code, unit, rate, gst, stock)
           VALUES (
             $1, $2,
             'ITEM-' || LPAD(nextval('items_item_code_seq')::text, 6, '0'),
             $3, $4, $5, $6
           )
           RETURNING id, item_code`,
          [
            categoryResult.rows[0]?.id ?? null,
            item.itemName,
            item.unit,
            item.rate,
            item.tax,
            item.qty,
          ],
        );
        item.itemId = insertedItem.rows[0].id;
        item.itemCode = insertedItem.rows[0].item_code;
      }

      await client.query(
        `INSERT INTO supplier_invoice_items (
            invoice_id, category, item_name, item_code, hsn_sac, qty, unit,
            rate, discount, tax, line_subtotal, line_tax, line_total
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          invoiceId,
          item.category,
          item.itemName,
          item.itemCode,
          String(item.hsnSac || '').trim(),
          item.qty,
          item.unit,
          item.rate,
          item.discount,
          item.tax,
          item.lineSubTotal,
          item.lineSubTotal * (item.tax / 100),
          item.lineSubTotal + item.lineSubTotal * (item.tax / 100),
        ],
      );

      await client.query(
        `INSERT INTO inventory_items (
            item_code, name, category, hsn_sac, unit, last_purchase_rate,
            supplier_name, available_stock, last_invoice_id
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
          item.itemCode,
          item.itemName,
          item.category,
          String(item.hsnSac || '').trim(),
          item.unit,
          item.rate,
          supplier.supplier_name,
          item.qty,
          invoiceId,
        ],
      );

      const catalogUpdate = await client.query(
        `UPDATE catalog_items
         SET item_name = $1, sku = $2, rate = $3, category = $4, updated_at = NOW()
         WHERE LOWER(sku) = LOWER($2) OR LOWER(item_name) = LOWER($1)`,
        [item.itemName, item.itemCode, item.rate, item.category],
      );
      if (catalogUpdate.rowCount === 0) {
        await client.query(
          `INSERT INTO catalog_items (category, item_name, sku, rate)
           VALUES ($1, $2, $3, $4)`,
          [item.category, item.itemName, item.itemCode, item.rate],
        );
      }
    }

    await client.query('COMMIT');
    return res.status(201).json({
      id: invoiceId,
      invoiceNo,
      supplier: supplier.supplier_name,
      supplierId: supplier.id,
      quantity: totalQuantity,
      itemsCount: normalizedItems.length,
      subTotal: financial.subTotal,
      taxTotal: financial.taxTotal,
      grandTotal: financial.grandTotal,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    const statusCode = error.statusCode || (error.code === '23505' ? 409 : 500);
    return res.status(statusCode).json({
      message: statusCode === 500 ? 'Unable to save warehouse receipt' : error.message,
    });
  } finally {
    client.release();
  }
}

module.exports = { handleWarehouseReceipt };
