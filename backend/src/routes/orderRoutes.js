const express = require('express');
const router = express.Router();

const {
getOrders,
deleteOrder,
getOrderDrafts,
getOrderById,
createOrder,
getCustomerOrders,
updateOrderStatus,
} = require('../controllers/orderController');

router.get('/', getOrders);
router.get('/drafts', getOrderDrafts);
router.get('/customer/:customerId', getCustomerOrders);
router.patch('/:id/status', updateOrderStatus);
router.get('/:id', getOrderById);
router.post('/', createOrder);
router.delete('/:id', deleteOrder);

module.exports = router;
