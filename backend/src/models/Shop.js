const mongoose = require('mongoose');

const shopSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Shop name is required'],
      trim: true,
      unique: true,
    },
    location: {
      type: String,
      required: [true, 'Shop location is required'],
      trim: true,
    },
    phone: {
      type: String,
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    description: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Virtual: get shopkeepers assigned to this shop
shopSchema.virtual('shopkeepers', {
  ref: 'User',
  localField: '_id',
  foreignField: 'shop',
  match: { role: 'shopkeeper', isActive: true },
});

module.exports = mongoose.model('Shop', shopSchema);
