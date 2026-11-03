const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

router.get('/', paymentController.getPayments);
router.post('/', paymentController.createPayment);
router.get('/customer/:customerId', paymentController.getCustomerPayments);

module.exports = router;
