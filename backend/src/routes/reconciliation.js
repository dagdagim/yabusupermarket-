const express = require('express');
const router = express.Router();
const {
  generateReconciliation,
  getReconciliations,
  updateReconciliation,
  getTodayReconciliation,
  deleteReconciliation,
} = require('../controllers/reconciliationController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect, authorize('admin'));

router.post('/generate', generateReconciliation);
router.get('/today', getTodayReconciliation);
router.get('/', getReconciliations);
router.put('/:id', updateReconciliation);
router.post('/:id/update', updateReconciliation);
router.delete('/:id', deleteReconciliation);
router.post('/:id/delete', deleteReconciliation);

module.exports = router;
