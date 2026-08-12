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

async function ensureDevData() {
  await upsertUser(DEV_ADMIN);
  await ensureShopLocations();

  const shopkeeperCount = await User.countDocuments({ role: 'shopkeeper' });
  if (shopkeeperCount > 0) return;

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

  logger.info('Dev shopkeeper accounts ready (kebede@yabusupermarket.com / mekdes@yabusupermarket.com — Shop@1234)');
}

module.exports = ensureDevData;
