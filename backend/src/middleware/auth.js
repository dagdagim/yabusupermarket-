const { verifyAccessToken } = require('../utils/jwt');
const User = require('../models/User');
const { errorResponse } = require('../utils/response');
const logger = require('../utils/logger');

const protect = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
      token = req.headers.authorization.split(' ')[1];
    } else if (req.query && req.query.token) {
      token = req.query.token;
    }

    if (!token) {
      return errorResponse(res, 'Not authorized. No token provided.', 401);
    }

    const decoded = verifyAccessToken(token);
    const user = await User.findById(decoded.id).populate('shop', 'name location isActive');

    if (!user) {
      return errorResponse(res, 'User no longer exists.', 401);
    }

    if (!user.isActive) {
      return errorResponse(res, 'Your account has been deactivated. Contact admin.', 403);
    }

    req.user = user;
    next();
  } catch (error) {
    logger.error('Auth middleware error:', error.message);
    if (error.name === 'JsonWebTokenError') {
      return errorResponse(res, 'Invalid token.', 401);
    }
    if (error.name === 'TokenExpiredError') {
      return errorResponse(res, 'Token expired.', 401);
    }
    return errorResponse(res, 'Not authorized.', 401);
  }
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return errorResponse(
        res,
        `Role '${req.user.role}' is not authorized for this action.`,
        403
      );
    }
    next();
  };
};

module.exports = { protect, authorize };
