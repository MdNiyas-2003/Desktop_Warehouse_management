const express = require('express');
const router = express.Router();
const supplierInvoiceController = require('../controllers/supplierInvoiceController');

router.get('/:supplierName', supplierInvoiceController.getSupplierInvoices);

module.exports = router;