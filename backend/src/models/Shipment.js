const mongoose = require('mongoose');

const shipmentSchema = new mongoose.Schema(
  {
    product: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: [true, 'Product is required'],
    },
    productName: {
      type: String,
      required: true,
      trim: true,
    },
    quantity: {
      type: Number,
      required: [true, 'Quantity is required'],
      min: [1, 'Quantity must be at least 1'],
    },
    shop: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shop',
      required: [true, 'Destination shop is required'],
    },
    shopName: {
      type: String,
      required: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ['pending', 'arrived'],
      default: 'pending',
    },
    shippedAt: {
      type: Date,
      default: Date.now,
    },
    arrivedAt: { type: Date },
    notes: {
      type: String,
      trim: true,
    },
  },
  { timestamps: true }
);

shipmentSchema.index({ status: 1, shippedAt: -1 });
shipmentSchema.index({ shop: 1, status: 1 });
shipmentSchema.index({ product: 1 });

module.exports = mongoose.model('Shipment', shipmentSchema);
