const mongoose = require('mongoose');

const saleItemSchema = new mongoose.Schema(
  {
    product: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: true,
    },
    productName: { type: String, required: true }, // snapshot at time of sale
    productSku: { type: String },
    quantitySold: {
      type: Number,
      required: true,
      min: [1, 'Quantity must be at least 1'],
    },
    unitPrice: {
      type: Number,
      required: true,
      min: [0],
    },
    purchasePrice: {
      type: Number,
      required: true,
    },
    totalPrice: {
      type: Number,
      required: true,
    },
    profit: {
      type: Number,
    },
  },
  { _id: false }
);

const saleSchema = new mongoose.Schema(
  {
    saleNumber: {
      type: String,
      unique: true,
    },
    items: [saleItemSchema],
    totalAmount: {
      type: Number,
      required: true,
      min: [0],
    },
    totalProfit: {
      type: Number,
      default: 0,
    },
    shop: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shop',
      required: true,
    },
    shopName: { type: String }, // snapshot
    shopkeeper: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    shopkeeperName: { type: String }, // snapshot
    status: {
      type: String,
      enum: ['completed', 'cancelled', 'refunded'],
      default: 'completed',
    },
    paymentMethod: {
      type: String,
      enum: ['cash', 'mobile_money', 'credit'],
      default: 'cash',
    },
    transferReceiptImage: { type: String },
    notes: { type: String },
    reconciledAt: { type: Date },
    reconciliationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Reconciliation',
    },
  },
  {
    timestamps: true,
  }
);

// Auto-generate sale number
saleSchema.pre('save', async function (next) {
  if (!this.saleNumber) {
    const date = new Date();
    const dateStr = `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}`;
    const count = await this.constructor.countDocuments();
    this.saleNumber = `SALE-${dateStr}-${String(count + 1).padStart(5, '0')}`;
  }
  // Calculate profits for each item
  this.items.forEach((item) => {
    item.profit = (item.unitPrice - item.purchasePrice) * item.quantitySold;
  });
  this.totalProfit = this.items.reduce((sum, item) => sum + (item.profit || 0), 0);
  next();
});

// Indexes
saleSchema.index({ shop: 1, createdAt: -1 });
saleSchema.index({ shopkeeper: 1, createdAt: -1 });
saleSchema.index({ createdAt: -1 });
saleSchema.index({ saleNumber: 1 });

module.exports = mongoose.model('Sale', saleSchema);
