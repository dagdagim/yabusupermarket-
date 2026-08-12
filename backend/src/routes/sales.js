const express = require('express');
const router = express.Router();
const {
  recordSale,
  getSales,
  getSale,
  getTodaySummary,
  getSalesAnalytics,
} = require('../controllers/salesController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect);

router.get('/summary/today', authorize('admin'), getTodaySummary);
router.get('/analytics', authorize('admin'), getSalesAnalytics);
router.get('/', getSales);
router.get('/:id', getSale);
router.post('/', recordSale);

module.exports = router;
