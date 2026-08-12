const express = require('express');
const router = express.Router();
const {
  getUsers,
  createUser,
  updateUser,
  toggleUserStatus,
  getShops,
  createShop,
  updateShop,
} = require('../controllers/userController');
const { protect, authorize } = require('../middleware/auth');

router.use(protect);

// Shop routes
router.get('/shops', getShops);
router.post('/shops', authorize('admin'), createShop);
router.put('/shops/:id', authorize('admin'), updateShop);

// User routes (admin only)
router.get('/', authorize('admin'), getUsers);
router.post('/', authorize('admin'), createUser);
router.put('/:id', authorize('admin'), updateUser);
router.put('/:id/toggle-status', authorize('admin'), toggleUserStatus);

module.exports = router;
