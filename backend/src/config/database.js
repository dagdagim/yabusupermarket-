const mongoose = require('mongoose');
const dns = require('dns');
try { dns.setServers(['8.8.8.8', '1.1.1.1']); } catch (e) {}
const logger = require('../utils/logger');
const ensureDevData = require('../utils/ensureDevData');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb+srv://dagimbekele_db_user:40M8kctSe79dyokU@cluster0.eiyhbw2.mongodb.net/autoparts?retryWrites=true&w=majority&appName=Cluster0';
  const maxAttempts = 10;
  const delayMs = 3000;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const conn = await mongoose.connect(uri, {
        family: 4,
        serverSelectionTimeoutMS: 15000,
      });
      logger.info(`MongoDB Connected: ${conn.connection.host}`);

      if (process.env.NODE_ENV === 'development') {
        await ensureDevData();
        logger.info('Dev login: admin@yabusupermarket.com / Admin@1234');
      }
      return;
    } catch (error) {
      const isLast = attempt === maxAttempts;
      if (isLast) {
        logger.error(`MongoDB connection error: ${error.message}`);
        process.exit(1);
      }
      logger.warn(
        `MongoDB not ready (attempt ${attempt}/${maxAttempts}): ${error.message}. Retrying in ${delayMs / 1000}s...`
      );
      await sleep(delayMs);
    }
  }
};

mongoose.connection.on('disconnected', () => {
  logger.warn('MongoDB disconnected. Attempting to reconnect...');
});

mongoose.connection.on('reconnected', () => {
  logger.info('MongoDB reconnected');
});

module.exports = connectDB;
