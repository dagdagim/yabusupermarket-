const User = require('../models/User');
const { generateAccessToken, generateRefreshToken, verifyRefreshToken } = require('../utils/jwt');
const { successResponse, errorResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Login
// @route   POST /api/auth/login
// @access  Public
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return errorResponse(res, 'Email and password are required.', 400);
    }

    const user = await User.findOne({ email })
      .select('+password +refreshToken')
      .populate('shop', 'name location isActive');

    if (!user) {
      return errorResponse(res, 'Invalid credentials.', 401);
    }

    if (!user.isActive) {
      return errorResponse(res, 'Account deactivated. Contact admin.', 403);
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return errorResponse(res, 'Invalid credentials.', 401);
    }

    // Check if shopkeeper's shop is active
    if (user.role === 'shopkeeper' && user.shop && !user.shop.isActive) {
      return errorResponse(res, 'Your assigned shop is inactive. Contact admin.', 403);
    }

    const accessToken = generateAccessToken(user._id, user.role);
    const refreshToken = generateRefreshToken(user._id);

    user.refreshToken = refreshToken;
    user.lastLogin = new Date();
    await user.save({ validateBeforeSave: false });

    logger.info(`User logged in: ${user.email} (${user.role})`);

    return successResponse(
      res,
      {
        accessToken,
        refreshToken,
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
          phone: user.phone,
          shop: user.shop,
          lastLogin: user.lastLogin,
        },
      },
      'Login successful'
    );
  } catch (error) {
    logger.error('Login error:', error);
    return errorResponse(res, 'Login failed. Please try again.', 500);
  }
};

// @desc    Refresh access token
// @route   POST /api/auth/refresh
// @access  Public
const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;

    if (!token) {
      return errorResponse(res, 'Refresh token required.', 400);
    }

    const decoded = verifyRefreshToken(token);
    const user = await User.findById(decoded.id).select('+refreshToken');

    if (!user || user.refreshToken !== token) {
      return errorResponse(res, 'Invalid refresh token.', 401);
    }

    const accessToken = generateAccessToken(user._id, user.role);
    const newRefreshToken = generateRefreshToken(user._id);

    user.refreshToken = newRefreshToken;
    await user.save({ validateBeforeSave: false });

    return successResponse(res, { accessToken, refreshToken: newRefreshToken }, 'Token refreshed');
  } catch (error) {
    return errorResponse(res, 'Token refresh failed.', 401);
  }
};

// @desc    Logout
// @route   POST /api/auth/logout
// @access  Private
const logout = async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user._id, { $unset: { refreshToken: 1 } });
    return successResponse(res, {}, 'Logged out successfully');
  } catch (error) {
    return errorResponse(res, 'Logout failed.', 500);
  }
};

// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).populate('shop', 'name location');
    return successResponse(res, { user }, 'Profile fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to get profile.', 500);
  }
};

// @desc    Change password
// @route   PUT /api/auth/change-password
// @access  Private
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return errorResponse(res, 'Current and new passwords are required.', 400);
    }

    if (newPassword.length < 6) {
      return errorResponse(res, 'New password must be at least 6 characters.', 400);
    }

    const user = await User.findById(req.user._id).select('+password');
    const isMatch = await user.comparePassword(currentPassword);

    if (!isMatch) {
      return errorResponse(res, 'Current password is incorrect.', 400);
    }

    user.password = newPassword;
    await user.save();

    return successResponse(res, {}, 'Password changed successfully');
  } catch (error) {
    return errorResponse(res, 'Failed to change password.', 500);
  }
};

module.exports = { login, refreshToken, logout, getMe, changePassword };
