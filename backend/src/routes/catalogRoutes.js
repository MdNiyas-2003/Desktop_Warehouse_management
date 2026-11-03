const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalogController');

router.get('/', catalogController.getCatalog);
router.post('/', catalogController.createCatalog);

module.exports = router;
