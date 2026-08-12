const User = require('../models/User');
const Shop = require('../models/Shop');
const { successResponse, errorResponse, paginatedResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Get all users
// @route   GET /api/users
// @access  Admin
const getUsers = async (req, res) => {
  try {
    const { page = 1, limit = 20, role, shop, isActive } = req.query;
    const skip = (page - 1) * limit;
    const filter = {};

    if (role) filter.role = role;
    if (shop) filter.shop = shop;
    if (isActive !== undefined) filter.isActive = isActive === 'true';

    const [users, total] = await Promise.all([
      User.find(filter)
        .populate('shop', 'name location')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      User.countDocuments(filter),
    ]);

    return paginatedResponse(res, users, total, page, limit, 'Users fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch users.', 500);
  }
};

// @desc    Create user (shopkeeper)
// @route   POST /api/users
// @access  Admin
const createUser = async (req, res) => {
  try {
    const { name, email, password, role, shopId, phone } = req.body;

    if (!name || !email || !password) {
      return errorResponse(res, 'Name, email, and password are required.', 400);
    }

    if (role === 'shopkeeper' && !shopId) {
      return errorResponse(res, 'Shop assignment is required for shopkeepers.', 400);
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return errorResponse(res, 'Email already in use.', 400);
    }

    if (shopId) {
      const shop = await Shop.findById(shopId);
      if (!shop) return errorResponse(res, 'Shop not found.', 404);
    }

    const user = await User.create({
      name,
      email,
      password,
      role: role || 'shopkeeper',
      shop: shopId,
      phone,
    });

    await user.populate('shop', 'name location');
    logger.info(`User created: ${user.email} (${user.role})`);
    return successResponse(res, { user }, 'User created successfully', 201);
  } catch (error) {
    if (error.code === 11000) {
      return errorResponse(res, 'Email already in use.', 400);
    }
    return errorResponse(res, 'Failed to create user.', 500);
  }
};

// @desc    Update user
// @route   PUT /api/users/:id
// @access  Admin
const updateUser = async (req, res) => {
  try {
    const { password, refreshToken, shopId, ...updateData } = req.body;

    const user = await User.findById(req.params.id).select('+password');
    if (!user) return errorResponse(res, 'User not found.', 404);

    if (updateData.email && updateData.email !== user.email) {
      const existingUser = await User.findOne({ email: updateData.email });
      if (existingUser) return errorResponse(res, 'Email already in use.', 400);
      user.email = updateData.email;
    }

    if (updateData.name !== undefined) user.name = updateData.name;
    if (updateData.phone !== undefined) user.phone = updateData.phone;
    if (updateData.role !== undefined) user.role = updateData.role;
    if (updateData.isActive !== undefined) user.isActive = updateData.isActive;
    if (shopId !== undefined) user.shop = shopId || undefined;

    if (user.role === 'shopkeeper' && !user.shop) {
      return errorResponse(res, 'Shop assignment is required for shopkeepers.', 400);
    }

    if (password !== undefined && password !== '') {
      if (password.length < 6) {
        return errorResponse(res, 'Password must be at least 6 characters.', 400);
      }
      user.password = password;
      user.refreshToken = undefined;
    }

    await user.save();
    await user.populate('shop', 'name location');

    return successResponse(res, { user }, 'User updated');
  } catch (error) {
    logger.error('Update user error:', error);
    if (error.name === 'ValidationError') {
      return errorResponse(res, error.message, 400);
    }
    return errorResponse(res, 'Failed to update user.', 500);
  }
};

// @desc    Toggle user active status
// @route   PUT /api/users/:id/toggle-status
// @access  Admin
const toggleUserStatus = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return errorResponse(res, 'User not found.', 404);

    if (user._id.toString() === req.user._id.toString()) {
      return errorResponse(res, 'Cannot deactivate your own account.', 400);
    }

    user.isActive = !user.isActive;
    await user.save({ validateBeforeSave: false });

    return successResponse(
      res,
      { isActive: user.isActive },
      `User ${user.isActive ? 'activated' : 'deactivated'}`
    );
  } catch (error) {
    return errorResponse(res, 'Failed to toggle user status.', 500);
  }
};

// @desc    Get all shops
// @route   GET /api/users/shops
// @access  Private
const getShops = async (req, res) => {
  try {
    const shops = await Shop.find({ isActive: true }).sort({ name: 1 });
    return successResponse(res, { shops }, 'Shops fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch shops.', 500);
  }
};

// @desc    Create shop
// @route   POST /api/users/shops
// @access  Admin
const createShop = async (req, res) => {
  try {
    const { name, location, phone, description } = req.body;

    if (!name || !location) {
      return errorResponse(res, 'Name and location are required.', 400);
    }

    const shop = await Shop.create({ name, location, phone, description });
    logger.info(`Shop created: ${shop.name}`);
    return successResponse(res, { shop }, 'Shop created successfully', 201);
  } catch (error) {
    if (error.code === 11000) {
      return errorResponse(res, 'Shop name already exists.', 400);
    }
    return errorResponse(res, 'Failed to create shop.', 500);
  }
};

// @desc    Update shop
// @route   PUT /api/users/shops/:id
// @access  Admin
const updateShop = async (req, res) => {
  try {
    const shop = await Shop.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!shop) return errorResponse(res, 'Shop not found.', 404);
    return successResponse(res, { shop }, 'Shop updated');
  } catch (error) {
    return errorResponse(res, 'Failed to update shop.', 500);
  }
};

module.exports = {
  getUsers,
  createUser,
  updateUser,
  toggleUserStatus,
  getShops,
  createShop,
  updateShop,
};
