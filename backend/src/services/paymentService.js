const PaymentModel = require("../models/paymentModel");

const PaymentService = {
  createPayment(data) {
    return PaymentModel.create(data);
  },

  getPayments() {
    return PaymentModel.getAll();
  },

  getCustomerPayments(customerId) {
    return PaymentModel.getByCustomer(customerId);
  },
};

module.exports = PaymentService;