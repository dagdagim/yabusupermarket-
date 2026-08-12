const express = require('express');
const router = express.Router();
const {
  getProducts,
  getProduct,
  getProductByQR,
  createProduct,
  updateProduct,
  deleteProduct,
  regenerateQR,
  getLowStockProducts,
} = require('../controllers/productController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect);

router.get('/low-stock', getLowStockProducts);
router.get('/qr/:qrData', getProductByQR);
router.get('/', getProducts);
router.get('/:id', getProduct);
router.post('/', authorize('admin'), createProduct);
router.put('/:id', authorize('admin'), updateProduct);
router.delete('/:id', authorize('admin'), deleteProduct);
router.post('/:id/qr', authorize('admin'), regenerateQR);

module.exports = router;
