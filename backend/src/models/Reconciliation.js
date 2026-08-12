const mongoose = require('mongoose');

const reconciliationSchema = new mongoose.Schema(
  {
    shop: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shop',
      required: true,
    },
    shopName: { type: String },
    date: {
      type: Date,
      required: true,
    },
    shopkeeper: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    shopkeeperName: { type: String },
    totalSales: {
      type: Number,
      default: 0,
    },
    totalTransactions: {
      type: Number,
      default: 0,
    },
    expectedCash: {
      type: Number,
      default: 0,
    },
    cashReceived: {
      type: Number,
      default: 0,
    },
    difference: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: ['pending', 'verified', 'completed'],
      default: 'pending',
    },
    notes: { type: String },
    verifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    verifiedAt: { type: Date },
    sales: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Sale',
      },
    ],
  },
  {
    timestamps: true,
  }
);

reconciliationSchema.index({ shop: 1, date: -1 });
reconciliationSchema.index({ status: 1 });

module.exports = mongoose.model('Reconciliation', reconciliationSchema);
