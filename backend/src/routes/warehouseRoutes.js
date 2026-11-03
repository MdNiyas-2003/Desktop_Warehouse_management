const express = require('express');
const router = express.Router();
const warehouseController = require('../controllers/warehouseController');

router.post('/receipts', warehouseController.handleWarehouseReceipt);
router.post('/receipt', warehouseController.handleWarehouseReceipt);

module.exports = router;
