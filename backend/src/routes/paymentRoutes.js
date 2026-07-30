const express = require("express");
const router = express.Router();

const PaymentController = require("../controllers/paymentController");

router.post("/", PaymentController.create);

router.get("/", PaymentController.getAll);

router.get("/customer/:customerId", PaymentController.getCustomerPayments);

module.exports = router;