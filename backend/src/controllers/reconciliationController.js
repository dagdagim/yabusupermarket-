const Reconciliation = require('../models/Reconciliation');
const Sale = require('../models/Sale');
const { successResponse, errorResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Create or get reconciliation for a shop/date
// @route   POST /api/reconciliation/generate
// @access  Admin
const generateReconciliation = async (req, res) => {
  try {
    const { shopId, date } = req.body;

    if (!shopId || !date) {
      return errorResponse(res, 'Shop ID and date are required.', 400);
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    // Check if reconciliation already exists
    let reconciliation = await Reconciliation.findOne({
      shop: shopId,
      date: { $gte: startOfDay, $lte: endOfDay },
    });

    if (reconciliation && reconciliation.status === 'completed') {
      return errorResponse(res, 'Reconciliation already completed for this date.', 400);
    }

    // Aggregate sales for the day/shop
    const salesAgg = await Sale.aggregate([
      {
        $match: {
          shop: new (require('mongoose').Types.ObjectId)(shopId),
          createdAt: { $gte: startOfDay, $lte: endOfDay },
          status: 'completed',
        },
      },
      {
        $group: {
          _id: null,
          totalSales: { $sum: '$totalAmount' },
          totalTransactions: { $sum: 1 },
          shopName: { $first: '$shopName' },
          shopkeeperName: { $first: '$shopkeeperName' },
          shopkeeper: { $first: '$shopkeeper' },
          saleIds: { $push: '$_id' },
        },
      },
    ]);

    const agg = salesAgg[0] || {
      totalSales: 0,
      totalTransactions: 0,
      saleIds: [],
      shopName: '',
      shopkeeperName: '',
    };

    const data = {
      shop: shopId,
      shopName: agg.shopName,
      date: targetDate,
      shopkeeper: agg.shopkeeper,
      shopkeeperName: agg.shopkeeperName,
      totalSales: agg.totalSales,
      totalTransactions: agg.totalTransactions,
      expectedCash: agg.totalSales,
      sales: agg.saleIds,
    };

    if (reconciliation) {
      Object.assign(reconciliation, data);
      await reconciliation.save();
    } else {
      reconciliation = await Reconciliation.create(data);
    }

    await reconciliation.populate('shop', 'name location');
    return successResponse(res, { reconciliation }, 'Reconciliation generated', 201);
  } catch (error) {
    logger.error('Generate reconciliation error:', error);
    return errorResponse(res, 'Failed to generate reconciliation.', 500);
  }
};

// @desc    Get all reconciliations
// @route   GET /api/reconciliation
// @access  Admin
const getReconciliations = async (req, res) => {
  try {
    const { shop, status, startDate, endDate, page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;
    const filter = {};

    if (shop) filter.shop = shop;
    if (status) filter.status = status;
    if (startDate || endDate) {
      filter.date = {};
      if (startDate) filter.date.$gte = new Date(startDate);
      if (endDate) filter.date.$lte = new Date(endDate);
    }

    const [reconciliations, total] = await Promise.all([
      Reconciliation.find(filter)
        .populate('shop', 'name location')
        .populate('shopkeeper', 'name')
        .populate('verifiedBy', 'name')
        .sort({ date: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Reconciliation.countDocuments(filter),
    ]);

    return successResponse(
      res,
      { reconciliations, total, page: parseInt(page), pages: Math.ceil(total / limit) },
      'Reconciliations fetched'
    );
  } catch (error) {
    return errorResponse(res, 'Failed to fetch reconciliations.', 500);
  }
};

// @desc    Update reconciliation (record cash received)
// @route   PUT /api/reconciliation/:id
// @access  Admin
const updateReconciliation = async (req, res) => {
  try {
    const { cashReceived, notes, status } = req.body;
    const reconciliation = await Reconciliation.findById(req.params.id);

    if (!reconciliation) {
      return errorResponse(res, 'Reconciliation not found.', 404);
    }

    if (reconciliation.status === 'completed') {
      return errorResponse(res, 'Cannot update a completed reconciliation.', 400);
    }

    if (cashReceived !== undefined) {
      reconciliation.cashReceived = cashReceived;
      reconciliation.difference = cashReceived - reconciliation.expectedCash;
    }

    if (notes) reconciliation.notes = notes;

    if (status) {
      reconciliation.status = status;
      if (status === 'verified' || status === 'completed') {
        reconciliation.verifiedBy = req.user._id;
        reconciliation.verifiedAt = new Date();
      }
    }

    await reconciliation.save();
    await reconciliation.populate([
      { path: 'shop', select: 'name location' },
      { path: 'verifiedBy', select: 'name' },
    ]);

    return successResponse(res, { reconciliation }, 'Reconciliation updated');
  } catch (error) {
    return errorResponse(res, 'Failed to update reconciliation.', 500);
  }
};

// @desc    Get today's reconciliation summary across all shops
// @route   GET /api/reconciliation/today
// @access  Admin
const getTodayReconciliation = async (req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const reconciliations = await Reconciliation.find({
      date: { $gte: startOfDay, $lte: endOfDay },
    }).populate('shop', 'name location');

    const totalExpected = reconciliations.reduce((s, r) => s + r.expectedCash, 0);
    const totalReceived = reconciliations.reduce((s, r) => s + r.cashReceived, 0);

    return successResponse(
      res,
      { reconciliations, totalExpected, totalReceived, difference: totalReceived - totalExpected },
      "Today's reconciliation fetched"
    );
  } catch (error) {
    return errorResponse(res, 'Failed to fetch today reconciliation.', 500);
  }
};

// @desc    Delete a reconciliation record
// @route   DELETE /api/reconciliation/:id
// @access  Admin
const deleteReconciliation = async (req, res) => {
  try {
    const reconciliation = await Reconciliation.findById(req.params.id);

    if (!reconciliation) {
      return errorResponse(res, 'Reconciliation record not found.', 404);
    }

    await Reconciliation.findByIdAndDelete(req.params.id);
    logger.info(`Reconciliation deleted: ${req.params.id}`);
    return successResponse(res, { id: req.params.id }, 'Reconciliation deleted successfully');
  } catch (error) {
    logger.error('Delete reconciliation error:', error);
    return errorResponse(res, 'Failed to delete reconciliation.', 500);
  }
};

module.exports = {
  generateReconciliation,
  getReconciliations,
  updateReconciliation,
  getTodayReconciliation,
  deleteReconciliation,
};
