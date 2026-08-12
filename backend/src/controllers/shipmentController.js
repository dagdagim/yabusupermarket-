const Shipment = require('../models/Shipment');
const Product = require('../models/Product');
const Shop = require('../models/Shop');
const { successResponse, errorResponse, paginatedResponse } = require('../utils/response');
const logger = require('../utils/logger');

// @desc    Record a product shipment to a destination shop
// @route   POST /api/shipments
// @access  Admin
const createShipment = async (req, res) => {
  try {
    const { productId, shopId, quantity, notes, shippedAt } = req.body;

    if (!productId || !shopId || !quantity) {
      return errorResponse(res, 'Product, destination shop, and quantity are required.', 400);
    }

    const parsedQuantity = Number(quantity);
    if (!Number.isFinite(parsedQuantity) || parsedQuantity < 1) {
      return errorResponse(res, 'Quantity must be at least 1.', 400);
    }

    const [product, shop] = await Promise.all([
      Product.findById(productId),
      Shop.findById(shopId),
    ]);

    if (!product || !product.isActive) {
      return errorResponse(res, 'Product not found.', 404);
    }
    if (!shop || !shop.isActive) {
      return errorResponse(res, 'Destination shop not found.', 404);
    }

    const shipment = new Shipment({
      product: product._id,
      productName: product.name,
      quantity: parsedQuantity,
      shop: shop._id,
      shopName: shop.name,
      notes,
      shippedAt: shippedAt ? new Date(shippedAt) : undefined,
    });

    await shipment.save();
    await shipment.populate([
      { path: 'product', select: 'name sku category quantity sellingPrice purchasePrice' },
      { path: 'shop', select: 'name location' },
    ]);

    logger.info(`Shipment recorded: ${shipment.productName} x ${shipment.quantity} to ${shipment.shopName}`);
    return successResponse(res, { shipment }, 'Shipment recorded successfully', 201);
  } catch (error) {
    logger.error('Create shipment error:', error);
    if (error.name === 'ValidationError') {
      return errorResponse(res, error.message, 400);
    }
    return errorResponse(res, 'Failed to record shipment.', 500);
  }
};

// @desc    Get shipments
// @route   GET /api/shipments
// @access  Admin
const getShipments = async (req, res) => {
  try {
    const { page = 1, limit = 50, status, shop, product } = req.query;
    const skip = (page - 1) * limit;
    const filter = {};

    if (status) filter.status = status;
    if (shop) filter.shop = shop;
    if (product) filter.product = product;

    const [shipments, total] = await Promise.all([
      Shipment.find(filter)
        .populate('product', 'name sku category quantity sellingPrice purchasePrice')
        .populate('shop', 'name location')
        .sort({ status: -1, shippedAt: -1, createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Shipment.countDocuments(filter),
    ]);

    return paginatedResponse(res, shipments, total, page, limit, 'Shipments fetched');
  } catch (error) {
    logger.error('Get shipments error:', error);
    return errorResponse(res, 'Failed to fetch shipments.', 500);
  }
};

// @desc    Verify shipment arrival and increment stock in the destination shop
// @route   PUT /api/shipments/:id/verify
// @access  Admin
const verifyArrival = async (req, res) => {
  try {
    const shipment = await Shipment.findById(req.params.id);
    if (!shipment) {
      return errorResponse(res, 'Shipment not found.', 404);
    }
    if (shipment.status === 'arrived') {
      return errorResponse(res, 'Shipment has already been verified.', 400);
    }

    const sourceProduct = await Product.findById(shipment.product);
    if (!sourceProduct) {
      return errorResponse(res, 'Original product not found.', 404);
    }

    let destinationProduct =
      sourceProduct.shop.toString() === shipment.shop.toString()
        ? sourceProduct
        : await Product.findOne({
            name: sourceProduct.name,
            category: sourceProduct.category,
            brand: sourceProduct.brand,
            vehicleType: sourceProduct.vehicleType,
            shop: shipment.shop,
            isActive: true,
          });

    if (!destinationProduct) {
      destinationProduct = await Product.create({
        name: sourceProduct.name,
        category: sourceProduct.category,
        brand: sourceProduct.brand,
        vehicleType: sourceProduct.vehicleType,
        description: sourceProduct.description,
        purchasePrice: sourceProduct.purchasePrice,
        sellingPrice: sourceProduct.sellingPrice,
        quantity: 0,
        lowStockThreshold: sourceProduct.lowStockThreshold,
        shop: shipment.shop,
        image: sourceProduct.image,
        createdBy: req.user._id,
      });
    }

    destinationProduct.quantity += shipment.quantity;
    await destinationProduct.save();

    shipment.status = 'arrived';
    shipment.arrivedAt = new Date();
    await shipment.save();
    await shipment.populate([
      { path: 'product', select: 'name sku category quantity sellingPrice purchasePrice' },
      { path: 'shop', select: 'name location' },
    ]);

    logger.info(`Shipment verified: ${shipment.productName} x ${shipment.quantity} to ${shipment.shopName}`);
    return successResponse(
      res,
      { shipment, product: destinationProduct },
      'Shipment arrival verified'
    );
  } catch (error) {
    logger.error('Verify shipment error:', error);
    return errorResponse(res, 'Failed to verify shipment.', 500);
  }
};

module.exports = {
  createShipment,
  getShipments,
  verifyArrival,
};
