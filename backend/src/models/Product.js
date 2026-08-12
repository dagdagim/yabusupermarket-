const mongoose = require('mongoose');

const CATEGORIES = [
  'Fresh Produce',
  'Dairy & Eggs',
  'Bakery',
  'Beverages',
  'Snacks & Sweets',
  'Pantry & Canned Goods',
  'Household & Cleaning',
  'Personal Care',
  'Meat & Seafood',
  'Frozen Foods',
];

const VEHICLE_TYPES = ['Piece', 'Kg', 'Gram', 'Liter', 'Pack', 'Bottle', 'Can', 'Box'];

const productSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Product name is required'],
      trim: true,
      maxlength: [200, 'Product name cannot exceed 200 characters'],
    },
    sku: {
      type: String,
      unique: true,
      uppercase: true,
      trim: true,
    },
    barcode: {
      type: String,
      trim: true,
      index: true,
    },
    category: {
      type: String,
      required: [true, 'Category is required'],
      enum: CATEGORIES,
    },
    brand: {
      type: String,
      trim: true,
    },
    vehicleType: {
      type: String,
      required: [true, 'Unit/Packaging type is required'],
      enum: VEHICLE_TYPES,
      default: 'Piece',
    },
    description: {
      type: String,
      trim: true,
    },
    purchasePrice: {
      type: Number,
      required: [true, 'Purchase price is required'],
      min: [0, 'Purchase price cannot be negative'],
    },
    sellingPrice: {
      type: Number,
      required: [true, 'Selling price is required'],
      min: [0, 'Selling price cannot be negative'],
    },
    quantity: {
      type: Number,
      required: [true, 'Quantity is required'],
      min: [0, 'Quantity cannot be negative'],
      default: 0,
    },
    lowStockThreshold: {
      type: Number,
      default: 5,
      min: [0, 'Low stock threshold cannot be negative'],
    },
    shop: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shop',
      required: [true, 'Shop is required'],
    },
    qrCode: {
      type: String, // base64 QR image or URL
    },
    qrCodeData: {
      type: String, // the raw data encoded in QR/Barcode (product ID or Barcode)
    },
    image: {
      type: String,
      default: '',
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Virtual: profit margin
productSchema.virtual('profitMargin').get(function () {
  if (!this.purchasePrice) return 0;
  return (
    (((this.sellingPrice - this.purchasePrice) / this.purchasePrice) * 100).toFixed(2)
  );
});

// Virtual: is low stock
productSchema.virtual('isLowStock').get(function () {
  return this.quantity <= this.lowStockThreshold;
});

// Auto-generate SKU before save
productSchema.pre('save', async function (next) {
  if (!this.sku) {
    const prefix = this.category.replace(/[^A-Z]/gi, '').substring(0, 3).toUpperCase();
    const rand = Math.floor(10000 + Math.random() * 90000);
    this.sku = `${prefix}-${rand}`;
  }
  next();
});

// Indexes for performance
productSchema.index({ shop: 1, isActive: 1 });
productSchema.index({ category: 1 });
productSchema.index({ name: 'text', brand: 'text', sku: 'text', barcode: 'text' });

module.exports = mongoose.model('Product', productSchema);
module.exports.CATEGORIES = CATEGORIES;
module.exports.VEHICLE_TYPES = VEHICLE_TYPES;

