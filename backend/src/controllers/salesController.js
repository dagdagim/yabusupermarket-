const Sale = require('../models/Sale');
const Product = require('../models/Product');
const { successResponse, errorResponse, paginatedResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Record a sale (QR-based)
// @route   POST /api/sales
// @access  Shopkeeper, Admin
const recordSale = async (req, res) => {
  try {
    const { items, paymentMethod = 'cash', notes, transferReceiptImage } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return errorResponse(res, 'At least one sale item is required.', 400);
    }

    // Validate all products exist and have enough stock
    const saleItems = [];
    let totalAmount = 0;

    for (const item of items) {
      const product = await Product.findById(item.productId).populate('shop', 'name');

      if (!product || !product.isActive) {
        return errorResponse(res, `Product not found: ${item.productId}`, 404);
      }

      // Shopkeepers can only sell from their shop
      if (
        req.user.role === 'shopkeeper' &&
        product.shop._id.toString() !== req.user.shop._id.toString()
      ) {
        return errorResponse(res, `Product ${product.name} does not belong to your shop.`, 403);
      }

      if (product.quantity < item.quantity) {
        return errorResponse(
          res,
          `Insufficient stock for ${product.name}. Available: ${product.quantity}`,
          400
        );
      }

      const itemTotal = product.sellingPrice * item.quantity;
      totalAmount += itemTotal;

      saleItems.push({
        product: product._id,
        productName: product.name,
        productSku: product.sku,
        quantitySold: item.quantity,
        unitPrice: product.sellingPrice,
        purchasePrice: product.purchasePrice,
        totalPrice: itemTotal,
      });

      // Decrement stock
      await Product.findByIdAndUpdate(product._id, {
        $inc: { quantity: -item.quantity },
      });

      // Emit low stock alert if needed
      const updatedProduct = await Product.findById(product._id);
      if (updatedProduct.quantity <= updatedProduct.lowStockThreshold) {
        const io = req.app.get('io');
        if (io) {
          io.to('admin-room').emit('low-stock-alert', {
            productId: product._id,
            productName: product.name,
            quantity: updatedProduct.quantity,
            threshold: updatedProduct.lowStockThreshold,
            shopName: product.shop.name,
          });
        }
      }
    }

    const shopId = req.user.role === 'shopkeeper' ? req.user.shop._id : saleItems[0] && req.body.shopId;

    const sale = new Sale({
      items: saleItems,
      totalAmount,
      shop: shopId,
      shopName: req.user.shop ? req.user.shop.name : req.body.shopName,
      shopkeeper: req.user._id,
      shopkeeperName: req.user.name,
      paymentMethod,
      transferReceiptImage,
      notes,
    });

    await sale.save();
    await sale.populate([
      { path: 'shop', select: 'name location' },
      { path: 'shopkeeper', select: 'name email' },
    ]);

    // Emit real-time sale event to admin
    const io = req.app.get('io');
    if (io) {
      io.to('admin-room').emit('new-sale', {
        sale,
        shopId: sale.shop._id,
        shopName: sale.shopName,
      });
    }

    logger.info(`Sale recorded: ${sale.saleNumber} | Total: ${totalAmount} ETB`);
    return successResponse(res, { sale }, 'Sale recorded successfully', 201);
  } catch (error) {
    logger.error('Record sale error:', error);
    return errorResponse(res, 'Failed to record sale.', 500);
  }
};

// @desc    Get all sales
// @route   GET /api/sales
// @access  Admin / Shopkeeper (own sales)
const getSales = async (req, res) => {
  try {
    const { page = 1, limit = 20, shop, shopkeeper, startDate, endDate, status } = req.query;
    const skip = (page - 1) * limit;

    const filter = {};

    if (req.user.role === 'shopkeeper') {
      filter.shopkeeper = req.user._id;
    } else {
      if (shop) filter.shop = shop;
      if (shopkeeper) filter.shopkeeper = shopkeeper;
    }

    if (status) filter.status = status;

    if (startDate || endDate) {
      filter.createdAt = {};
      if (startDate) filter.createdAt.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        filter.createdAt.$lte = end;
      }
    }

    const [sales, total] = await Promise.all([
      Sale.find(filter)
        .populate('shop', 'name location')
        .populate('shopkeeper', 'name email')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Sale.countDocuments(filter),
    ]);

    return paginatedResponse(res, sales, total, page, limit, 'Sales fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch sales.', 500);
  }
};

// @desc    Get single sale
// @route   GET /api/sales/:id
// @access  Private
const getSale = async (req, res) => {
  try {
    const sale = await Sale.findById(req.params.id)
      .populate('shop', 'name location')
      .populate('shopkeeper', 'name email')
      .populate('items.product', 'name sku category');

    if (!sale) return errorResponse(res, 'Sale not found.', 404);

    // Shopkeeper can only see own sales
    if (
      req.user.role === 'shopkeeper' &&
      sale.shopkeeper._id.toString() !== req.user._id.toString()
    ) {
      return errorResponse(res, 'Not authorized.', 403);
    }

    return successResponse(res, { sale }, 'Sale fetched');
  } catch (error) {
    return errorResponse(res, 'Failed to fetch sale.', 500);
  }
};

// @desc    Get today's sales summary
// @route   GET /api/sales/summary/today
// @access  Admin
const getTodaySummary = async (req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const summary = await Sale.aggregate([
      {
        $match: {
          createdAt: { $gte: startOfDay, $lte: endOfDay },
          status: 'completed',
        },
      },
      {
        $group: {
          _id: '$shop',
          shopName: { $first: '$shopName' },
          totalRevenue: { $sum: '$totalAmount' },
          totalProfit: { $sum: '$totalProfit' },
          totalTransactions: { $sum: 1 },
          totalItemsSold: { $sum: { $sum: '$items.quantitySold' } },
        },
      },
      { $sort: { totalRevenue: -1 } },
    ]);

    const overall = summary.reduce(
      (acc, s) => ({
        totalRevenue: acc.totalRevenue + s.totalRevenue,
        totalProfit: acc.totalProfit + s.totalProfit,
        totalTransactions: acc.totalTransactions + s.totalTransactions,
        totalItemsSold: acc.totalItemsSold + s.totalItemsSold,
      }),
      { totalRevenue: 0, totalProfit: 0, totalTransactions: 0, totalItemsSold: 0 }
    );

    return successResponse(res, { summary, overall }, "Today's summary fetched");
  } catch (error) {
    return errorResponse(res, 'Failed to fetch summary.', 500);
  }
};

// @desc    Get sales analytics (weekly/monthly)
// @route   GET /api/sales/analytics
// @access  Admin
const getSalesAnalytics = async (req, res) => {
  try {
    const { period = 'weekly', shop } = req.query;
    const now = new Date();
    let startDate;

    if (period === 'weekly') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
    } else if (period === 'monthly') {
      startDate = new Date(now.getFullYear(), now.getMonth() - 11, 1);
    } else {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    const matchStage = {
      createdAt: { $gte: startDate },
      status: 'completed',
    };
    if (shop) matchStage.shop = new (require('mongoose').Types.ObjectId)(shop);

    const groupStage =
      period === 'monthly'
        ? {
            _id: { year: { $year: '$createdAt' }, month: { $month: '$createdAt' } },
            revenue: { $sum: '$totalAmount' },
            profit: { $sum: '$totalProfit' },
            transactions: { $sum: 1 },
          }
        : {
            _id: {
              year: { $year: '$createdAt' },
              month: { $month: '$createdAt' },
              day: { $dayOfMonth: '$createdAt' },
            },
            revenue: { $sum: '$totalAmount' },
            profit: { $sum: '$totalProfit' },
            transactions: { $sum: 1 },
          };

    const analytics = await Sale.aggregate([
      { $match: matchStage },
      { $group: groupStage },
      { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } },
    ]);

    // Top selling products
    const topProducts = await Sale.aggregate([
      { $match: matchStage },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.product',
          productName: { $first: '$items.productName' },
          totalSold: { $sum: '$items.quantitySold' },
          totalRevenue: { $sum: '$items.totalPrice' },
        },
      },
      { $sort: { totalSold: -1 } },
      { $limit: 10 },
    ]);

    return successResponse(res, { analytics, topProducts }, 'Analytics fetched');
  } catch (error) {
    logger.error('Analytics error:', error);
    return errorResponse(res, 'Failed to fetch analytics.', 500);
  }
};

module.exports = {
  recordSale,
  getSales,
  getSale,
  getTodaySummary,
  getSalesAnalytics,
};
