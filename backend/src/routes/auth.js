// routes/auth.js
const express = require('express');
const router = express.Router();
const { login, refreshToken, logout, getMe, changePassword } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

router.post('/login', login);
router.post('/refresh', refreshToken);
router.post('/logout', protect, logout);
router.get('/me', protect, getMe);
router.put('/change-password', protect, changePassword);

module.exports = router;
