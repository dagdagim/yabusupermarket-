const express = require('express');
const router = express.Router();
const {
  createShipment,
  getShipments,
  verifyArrival,
} = require('../controllers/shipmentController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect);
router.use(authorize('admin'));

router.get('/', getShipments);
router.post('/', createShipment);
router.put('/:id/verify', verifyArrival);

module.exports = router;
