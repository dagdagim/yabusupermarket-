require('dotenv').config();
const dns = require('dns');
try { dns.setServers(['8.8.8.8', '1.1.1.1']); } catch(e) {}
const mongoose = require('mongoose');
const User = require('../models/User');
const Shop = require('../models/Shop');
const Product = require('../models/Product');
const QRCode = require('qrcode');
const logger = require('./logger');

async function createProductWithQr(data) {
  const product = new Product(data);
  await product.save();
  const qrData = data.barcode || product._id.toString();
  product.qrCode = await QRCode.toDataURL(qrData, {
    errorCorrectionLevel: 'H',
    width: 300,
  });
  product.qrCodeData = qrData;
  if (!product.barcode) product.barcode = qrData;
  await product.save();
  return product;
}

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('Connected to database for Yabu Supermarket seeding...');

    await Promise.all([
      User.deleteMany(),
      Shop.deleteMany(),
      Product.deleteMany(),
    ]);

    const [shopA, shopB] = await Shop.create([
      {
        name: 'Yabu Supermarket - Main',
        location: 'Negelle Borena Main St.',
        phone: '+251911111111',
      },
      {
        name: 'Yabu Supermarket - Branch 2',
        location: 'Negelle Borena North',
        phone: '+251922222222',
      },
    ]);

    await User.create({
      name: 'Admin User',
      email: 'admin@yabusupermarket.com',
      password: 'Admin@1234',
      role: 'admin',
    });

    await User.create([
      {
        name: 'Kebede Alemu',
        email: 'kebede@yabusupermarket.com',
        password: 'Shop@1234',
        role: 'shopkeeper',
        shop: shopA._id,
        phone: '+251911000001',
      },
      {
        name: 'Mekdes Tadesse',
        email: 'mekdes@yabusupermarket.com',
        password: 'Shop@1234',
        role: 'shopkeeper',
        shop: shopB._id,
        phone: '+251922000002',
      },
    ]);

    const productData = [
      // —— Shop A (Main Branch) ——
      {
        name: 'Organic Bananas (1kg)',
        barcode: '6001234567011',
        category: 'Fresh Produce',
        brand: 'Fresh Farm',
        vehicleType: 'Kg',
        description: 'Fresh ripe sweet yellow bananas',
        purchasePrice: 60,
        sellingPrice: 95,
        quantity: 50,
        shop: shopA._id,
      },
      {
        name: 'Fresh Red Apples (1kg)',
        barcode: '6001234567028',
        category: 'Fresh Produce',
        brand: 'Orchard Select',
        vehicleType: 'Kg',
        description: 'Crisp juicy red apples',
        purchasePrice: 180,
        sellingPrice: 250,
        quantity: 35,
        shop: shopA._id,
      },
      {
        name: 'Fresh Whole Milk 1L',
        barcode: '6001234567042',
        category: 'Dairy & Eggs',
        brand: 'Family Dairy',
        vehicleType: 'Liter',
        description: 'Pasteurized whole milk 1 Liter pack',
        purchasePrice: 70,
        sellingPrice: 110,
        quantity: 60,
        shop: shopA._id,
      },
      {
        name: 'Farm Fresh Eggs (12-pack)',
        barcode: '6001234567059',
        category: 'Dairy & Eggs',
        brand: 'Golden Egg',
        vehicleType: 'Pack',
        description: 'Large Grade A fresh brown eggs',
        purchasePrice: 160,
        sellingPrice: 220,
        quantity: 40,
        shop: shopA._id,
      },
      {
        name: 'Whole Wheat Bread 400g',
        barcode: '6001234567080',
        category: 'Bakery',
        brand: 'Daily Bake',
        vehicleType: 'Piece',
        description: 'Freshly baked sliced whole wheat loaf',
        purchasePrice: 40,
        sellingPrice: 65,
        quantity: 30,
        shop: shopA._id,
      },
      {
        name: 'Coca Cola 500ml',
        barcode: '5449000000996',
        category: 'Beverages',
        brand: 'Coca Cola',
        vehicleType: 'Bottle',
        description: 'Chilled sparkling soft drink',
        purchasePrice: 35,
        sellingPrice: 50,
        quantity: 120,
        shop: shopA._id,
      },
      {
        name: 'Ethiopian Arabica Coffee Beans 250g',
        barcode: '6001234567127',
        category: 'Beverages',
        brand: 'Yabu Roast',
        vehicleType: 'Pack',
        description: 'Premium roasted Yirgacheffe single origin coffee',
        purchasePrice: 220,
        sellingPrice: 350,
        quantity: 25,
        shop: shopA._id,
      },
      {
        name: 'Basmati Rice 5kg',
        barcode: '6001234567158',
        category: 'Pantry & Canned Goods',
        brand: 'Royal Grain',
        vehicleType: 'Pack',
        description: 'Long grain aromatic white basmati rice',
        purchasePrice: 650,
        sellingPrice: 920,
        quantity: 18,
        shop: shopA._id,
      },
      {
        name: 'Extra Virgin Olive Oil 1L',
        barcode: '6001234567165',
        category: 'Pantry & Canned Goods',
        brand: 'Borgata',
        vehicleType: 'Bottle',
        description: 'Cold pressed extra virgin olive oil',
        purchasePrice: 550,
        sellingPrice: 780,
        quantity: 12,
        shop: shopA._id,
      },
      {
        name: 'Dishwashing Liquid 750ml',
        barcode: '6001234567196',
        category: 'Household & Cleaning',
        brand: 'CleanMax',
        vehicleType: 'Bottle',
        description: 'Grease cutting lemon fragrance dish soap',
        purchasePrice: 120,
        sellingPrice: 185,
        quantity: 25,
        shop: shopA._id,
      },

      // —— Shop B (Branch 2) ——
      {
        name: 'Fresh Tomatoes (1kg)',
        barcode: '6001234567035',
        category: 'Fresh Produce',
        brand: 'Fresh Farm',
        vehicleType: 'Kg',
        description: 'Red ripe garden tomatoes',
        purchasePrice: 50,
        sellingPrice: 80,
        quantity: 40,
        shop: shopB._id,
      },
      {
        name: 'Greek Yogurt 500g',
        barcode: '6001234567073',
        category: 'Dairy & Eggs',
        brand: 'Family Dairy',
        vehicleType: 'Gram',
        description: 'Rich creamy plain Greek yogurt',
        purchasePrice: 110,
        sellingPrice: 165,
        quantity: 20,
        shop: shopB._id,
      },
      {
        name: 'Mineral Water 1.5L',
        barcode: '6001234567103',
        category: 'Beverages',
        brand: 'Pure Spring',
        vehicleType: 'Bottle',
        description: 'Natural mineral spring water',
        purchasePrice: 20,
        sellingPrice: 35,
        quantity: 100,
        shop: shopB._id,
      },
      {
        name: 'Lays Potato Chips Classic 150g',
        barcode: '6001234567134',
        category: 'Snacks & Sweets',
        brand: 'Lays',
        vehicleType: 'Pack',
        description: 'Crispy salted potato chips',
        purchasePrice: 75,
        sellingPrice: 120,
        quantity: 45,
        shop: shopB._id,
      },
      {
        name: 'Italian Spaghetti 500g',
        barcode: '6001234567172',
        category: 'Pantry & Canned Goods',
        brand: 'Barilla',
        vehicleType: 'Pack',
        description: 'Durum wheat semolina pasta',
        purchasePrice: 80,
        sellingPrice: 130,
        quantity: 30,
        shop: shopB._id,
      },
      {
        name: 'Laundry Detergent Powder 2kg',
        barcode: '6001234567202',
        category: 'Household & Cleaning',
        brand: 'Omo',
        vehicleType: 'Pack',
        description: 'Active stain removal washing powder',
        purchasePrice: 310,
        sellingPrice: 440,
        quantity: 15,
        shop: shopB._id,
      },
      {
        name: 'Herbal Toothpaste 100g',
        barcode: '6001234567219',
        category: 'Personal Care',
        brand: 'Colgate',
        vehicleType: 'Piece',
        description: 'Cavity protection herbal toothpaste',
        purchasePrice: 65,
        sellingPrice: 105,
        quantity: 35,
        shop: shopB._id,
      },
      {
        name: 'Fresh Chicken Breast 1kg',
        barcode: '6001234567233',
        category: 'Meat & Seafood',
        brand: 'Prime Meat',
        vehicleType: 'Kg',
        description: 'Skinless boneless fresh chicken breast',
        purchasePrice: 290,
        sellingPrice: 420,
        quantity: 12,
        shop: shopB._id,
      },
      {
        name: 'Vanilla Ice Cream 1L',
        barcode: '6001234567240',
        category: 'Frozen Foods',
        brand: 'Creamy Delights',
        vehicleType: 'Box',
        description: 'Rich French vanilla tub',
        purchasePrice: 190,
        sellingPrice: 280,
        quantity: 10,
        shop: shopB._id,
      },
    ];

    for (const pd of productData) {
      await createProductWithQr(pd);
    }

    logger.info(`✅ Yabu Supermarket Seeding complete! ${productData.length} products created.`);
    logger.info('Admin:       admin@yabusupermarket.com / Admin@1234');
    logger.info('Shopkeeper1: kebede@yabusupermarket.com / Shop@1234 (Yabu Supermarket - Main)');
    logger.info('Shopkeeper2: mekdes@yabusupermarket.com / Shop@1234 (Yabu Supermarket - Branch 2)');

    process.exit(0);
  } catch (error) {
    logger.error('Seeding failed:', error);
    process.exit(1);
  }
};

seed();
