const QRCode = require('qrcode');
const Product = require('../models/Product');
const { successResponse, errorResponse, paginatedResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Get all products (admin) / shop products (shopkeeper)
// @route   GET /api/products
// @access  Private
const getProducts = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, category, vehicleType, shop, lowStock } = req.query;
    const skip = (page - 1) * limit;

    const filter = { isActive: true };

    // Shopkeepers can only see their shop's products
    if (req.user.role === 'shopkeeper') {
      filter.shop = req.user.shop._id;
    } else if (shop) {
      filter.shop = shop;
    }

    if (category) filter.category = category;
    if (vehicleType) filter.vehicleType = vehicleType;
    if (lowStock === 'true') {
      filter.$expr = { $lte: ['$quantity', '$lowStockThreshold'] };
    }
    if (search) {
      filter.$text = { $search: search };
    }

    const [products, total] = await Promise.all([
      Product.find(filter)
        .populate('shop', 'name location')
        .populate('createdBy', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Product.countDocuments(filter),
    ]);

    return paginatedResponse(res, products, total, page, limit, 'Products fetched');
  } catch (error) {
    logger.error('Get products error:', error);
    return errorResponse(res, 'Failed to fetch products.', 500);
  }
};

// @desc    Get single product
// @route   GET /api/products/:id
// @access  Private
const getProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id)
      .populate('shop', 'name location')
      .populate('createdBy', 'name');

    if (!product || !product.isActive) {
      return errorResponse(res, 'Product not found.', 404);
    }

    return successResponse(res, { product }, 'Product fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch product.', 500);
  }
};

const mongoose = require('mongoose');

// @desc    Get product by QR or Barcode data (for scanning)
// @route   GET /api/products/qr/:qrData
// @access  Private
const getProductByQR = async (req, res) => {
  try {
    const code = req.params.qrData;
    const isObjId = mongoose.Types.ObjectId.isValid(code);
    
    const query = {
      isActive: true,
      $or: [
        { qrCodeData: code },
        { barcode: code },
        { sku: code },
        ...(isObjId ? [{ _id: code }] : []),
      ],
    };

    const product = await Product.findOne(query).populate('shop', 'name location');

    if (!product) {
      return errorResponse(res, 'Product not found for this code or barcode.', 404);
    }

    return successResponse(res, { product }, 'Product found');
  } catch (error) {
    logger.error('Get product by QR error:', error);
    return errorResponse(res, 'Failed to fetch product by QR/Barcode.', 500);
  }
};

// @desc    Create product
// @route   POST /api/products
// @access  Admin
const createProduct = async (req, res) => {
  try {
    const productData = { ...req.body, createdBy: req.user._id };
    const product = new Product(productData);
    await product.save();

    // Generate QR code encoding barcode or _id
    const qrData = product.barcode || product._id.toString();
    const qrCodeBase64 = await QRCode.toDataURL(qrData, {
      errorCorrectionLevel: 'H',
      type: 'image/png',
      width: 300,
      margin: 2,
      color: { dark: '#000000', light: '#FFFFFF' },
    });

    product.qrCode = qrCodeBase64;
    product.qrCodeData = qrData;
    await product.save();

    await product.populate('shop', 'name location');

    logger.info(`Product created: ${product.name} (${product.sku}) - Barcode: ${product.barcode || 'N/A'}`);
    return successResponse(res, { product }, 'Product created successfully', 201);
  } catch (error) {
    logger.error('Create product error:', error);
    if (error.name === 'ValidationError') {
      return errorResponse(res, error.message, 400);
    }
    return errorResponse(res, 'Failed to create product.', 500);
  }
};

// @desc    Update product
// @route   PUT /api/products/:id
// @access  Admin
const updateProduct = async (req, res) => {
  try {
    const { qrCode, qrCodeData, createdBy, ...updateData } = req.body;

    const product = await Product.findByIdAndUpdate(
      req.params.id,
      { $set: updateData },
      { new: true, runValidators: true }
    ).populate('shop', 'name location');

    if (!product) {
      return errorResponse(res, 'Product not found.', 404);
    }

    logger.info(`Product updated: ${product.name}`);
    return successResponse(res, { product }, 'Product updated successfully');
  } catch (error) {
    if (error.name === 'ValidationError') {
      return errorResponse(res, error.message, 400);
    }
    return errorResponse(res, 'Failed to update product.', 500);
  }
};

// @desc    Delete (soft) product
// @route   DELETE /api/products/:id
// @access  Admin
const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByIdAndUpdate(
      req.params.id,
      { isActive: false },
      { new: true }
    );

    if (!product) {
      return errorResponse(res, 'Product not found.', 404);
    }

    logger.info(`Product deleted: ${product.name}`);
    return successResponse(res, {}, 'Product deleted successfully');
  } catch (error) {
    return errorResponse(res, 'Failed to delete product.', 500);
  }
};

// @desc    Regenerate QR code
// @route   POST /api/products/:id/qr
// @access  Admin
const regenerateQR = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return errorResponse(res, 'Product not found.', 404);
    }

    const qrData = product._id.toString();
    const qrCodeBase64 = await QRCode.toDataURL(qrData, {
      errorCorrectionLevel: 'H',
      width: 300,
      margin: 2,
    });

    product.qrCode = qrCodeBase64;
    product.qrCodeData = qrData;
    await product.save();

    return successResponse(res, { qrCode: qrCodeBase64 }, 'QR code regenerated');
  } catch (error) {
    return errorResponse(res, 'Failed to regenerate QR code.', 500);
  }
};

// @desc    Get low stock products
// @route   GET /api/products/low-stock
// @access  Admin
const getLowStockProducts = async (req, res) => {
  try {
    const shop = req.user.role === 'shopkeeper' ? req.user.shop._id : req.query.shop;
    const filter = {
      isActive: true,
      $expr: { $lte: ['$quantity', '$lowStockThreshold'] },
    };
    if (shop) filter.shop = shop;

    const products = await Product.find(filter)
      .populate('shop', 'name')
      .sort({ quantity: 1 });

    return successResponse(res, { products, count: products.length }, 'Low stock products fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch low stock products.', 500);
  }
};

module.exports = {
  getProducts,
  getProduct,
  getProductByQR,
  createProduct,
  updateProduct,
  deleteProduct,
  regenerateQR,
  getLowStockProducts,
};
