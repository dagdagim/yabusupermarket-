const express = require('express');
const reconRouter = express.Router();
const reportRouter = express.Router();

const {
  generateReconciliation,
  getReconciliations,
  updateReconciliation,
  getTodayReconciliation,
  deleteReconciliation,
} = require('../controllers/reconciliationController');
const { getReport, exportExcel, exportPDF } = require('../controllers/reportController');
const { protect, authorize } = require('../middleware/auth');

// Reconciliation routes
reconRouter.use(protect, authorize('admin'));
reconRouter.post('/generate', generateReconciliation);
reconRouter.get('/today', getTodayReconciliation);
reconRouter.get('/', getReconciliations);
reconRouter.put('/:id', updateReconciliation);
reconRouter.delete('/:id', deleteReconciliation);

// Report routes
reportRouter.use(protect, authorize('admin'));
reportRouter.get('/', getReport);
reportRouter.get('/export/excel', exportExcel);
reportRouter.get('/export/pdf', exportPDF);

module.exports = { reconRouter, reportRouter };
