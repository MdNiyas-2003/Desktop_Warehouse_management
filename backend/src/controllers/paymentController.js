const PaymentService = require("../services/paymentService");

const PaymentController = {
  async create(req, res) {
    try {
      const payment = await PaymentService.createPayment(req.body);

      res.status(201).json({
        success: true,
        message: "Payment saved successfully.",
        data: payment,
      });
    } catch (err) {
      console.error(err);

      res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  },

  async getAll(req, res) {
    try {
      const payments = await PaymentService.getPayments();

      res.json(payments);
    } catch (err) {
      console.error(err);

      res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  },

  async getCustomerPayments(req, res) {
    try {
      const payments = await PaymentService.getCustomerPayments(
        req.params.customerId
      );

      res.json(payments);
    } catch (err) {
      console.error(err);

      res.status(500).json({
        success: false,
        message: err.message,
      });
    }
  },
};

module.exports = PaymentController;