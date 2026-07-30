const db = require("../db");

const PaymentModel = {
  async create(payment) {
    const query = `
      INSERT INTO payments
      (
        customer_id,
        invoice_id,
        payment_date,
        payment_method,
        reference_no,
        cheque_no,
        cheque_date,
        amount,
        notes
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      RETURNING *;
    `;

    const values = [
      payment.customer_id,
      payment.invoice_id,
      payment.payment_date,
      payment.payment_method,
      payment.reference_no,
      payment.cheque_no,
      payment.cheque_date,
      payment.amount,
      payment.notes,
    ];

    const result = await db.query(query, values);

    return result.rows[0];
  },

  async getAll() {
    const result = await db.query(`
      SELECT *
      FROM payments
      ORDER BY payment_date DESC
    `);

    return result.rows;
  },

  async getByCustomer(customerId) {
    const result = await db.query(
      `
      SELECT *
      FROM payments
      WHERE customer_id=$1
      ORDER BY payment_date ASC
      `,
      [customerId]
    );

    return result.rows;
  },
};

module.exports = PaymentModel;