const User = require('../models/User');
const Shop = require('../models/Shop');
const logger = require('./logger');

const DEV_ADMIN = {
  name: 'Admin User',
  email: 'admin@yabusupermarket.com',
  password: 'Admin@1234',
  role: 'admin',
};

const DEV_SHOPKEEPERS = [
  {
    name: 'Kebede Alemu',
    email: 'kebede@yabusupermarket.com',
    password: 'Shop@1234',
    shopName: 'Yabu Supermarket - Main',
    phone: '+251911000001',
  },
  {
    name: 'Mekdes Tadesse',
    email: 'mekdes@yabusupermarket.com',
    password: 'Shop@1234',
    shopName: 'Yabu Supermarket - Branch 2',
    phone: '+251922000002',
  },
];

async function upsertUser({ email, password, ...fields }) {
  let user = await User.findOne({ email }).select('+password');
  if (!user) {
    user = await User.create({ email, password, ...fields });
    logger.info(`Created dev user: ${email}`);
    return user;
  }

  const passwordOk = await user.comparePassword(password);
  if (!passwordOk) {
    user.password = password;
    await user.save();
    logger.info(`Reset dev password for: ${email}`);
  }
  return user;
}

/**
 * Ensures default dev accounts exist with known passwords.
 * Runs only when NODE_ENV=development.
 */
const SHOP_UPDATES = [
  { legacyName: 'MasreSuk', name: 'Yabu Supermarket - Main', location: 'Negelle Borena' },
  { legacyName: 'Shop 2', name: 'Yabu Supermarket - Branch 2', location: 'Negelle Borena' },
];

async function ensureShopLocations() {
  for (const s of SHOP_UPDATES) {
    await Shop.updateOne(
      { name: s.legacyName },
      { $set: { name: s.name, location: s.location } }
    );
    await Shop.updateOne(
      { name: s.name },
      { $set: { location: s.location } }
    );
  }
}

const Product = require('../models/Product');
const Sale = require('../models/Sale');

async function ensureSampleSales() {
  const saleCount = await Sale.countDocuments();
  if (saleCount > 0) return;

  const kebede = await User.findOne({ email: 'kebede@yabusupermarket.com' });
  const mekdes = await User.findOne({ email: 'mekdes@yabusupermarket.com' });

  if (kebede && kebede.shop) {
    const products = await Product.find({ shop: kebede.shop }).limit(3);
    if (products.length > 0) {
      const p1 = products[0];
      const p2 = products[1] || products[0];
      const s1 = new Sale({
        items: [
          {
            product: p1._id,
            productName: p1.name,
            productSku: p1.sku,
            quantitySold: 2,
            unitPrice: p1.sellingPrice,
            purchasePrice: p1.purchasePrice,
            totalPrice: p1.sellingPrice * 2,
          },
          {
            product: p2._id,
            productName: p2.name,
            productSku: p2.sku,
            quantitySold: 1,
            unitPrice: p2.sellingPrice,
            purchasePrice: p2.purchasePrice,
            totalPrice: p2.sellingPrice * 1,
          },
        ],
        totalAmount: p1.sellingPrice * 2 + p2.sellingPrice * 1,
        shop: kebede.shop,
        shopName: 'Yabu Supermarket - Main',
        shopkeeper: kebede._id,
        shopkeeperName: kebede.name,
        paymentMethod: 'cash',
      });
      await s1.save();
    }
  }

  if (mekdes && mekdes.shop) {
    const products = await Product.find({ shop: mekdes.shop }).limit(2);
    if (products.length > 0) {
      const p1 = products[0];
      const s2 = new Sale({
        items: [
          {
            product: p1._id,
            productName: p1.name,
            productSku: p1.sku,
            quantitySold: 1,
            unitPrice: p1.sellingPrice,
            purchasePrice: p1.purchasePrice,
            totalPrice: p1.sellingPrice * 1,
          },
        ],
        totalAmount: p1.sellingPrice * 1,
        shop: mekdes.shop,
        shopName: 'Yabu Supermarket - Branch 2',
        shopkeeper: mekdes._id,
        shopkeeperName: mekdes.name,
        paymentMethod: 'mobile_money',
      });
      await s2.save();
    }
  }
  logger.info('Sample sales created for Kebede and Mekdes.');
}

async function ensureDevData() {
  await upsertUser(DEV_ADMIN);
  await ensureShopLocations();

  const shopkeeperCount = await User.countDocuments({ role: 'shopkeeper' });
  if (shopkeeperCount === 0) {
    const [shopA, shopB] = await Shop.create([
      { name: 'Yabu Supermarket - Main', location: 'Negelle Borena', phone: '+251911111111' },
      { name: 'Yabu Supermarket - Branch 2', location: 'Negelle Borena', phone: '+251922222222' },
    ]);

    const shops = [shopA, shopB];
    for (let i = 0; i < DEV_SHOPKEEPERS.length; i++) {
      const sk = DEV_SHOPKEEPERS[i];
      await upsertUser({
        name: sk.name,
        email: sk.email,
        password: sk.password,
        role: 'shopkeeper',
        shop: shops[i]._id,
        phone: sk.phone,
      });
    }
  }

  await ensureSampleSales();
  logger.info('Dev shopkeeper accounts ready (kebede@yabusupermarket.com / mekdes@yabusupermarket.com — Shop@1234)');
}

module.exports = ensureDevData;
