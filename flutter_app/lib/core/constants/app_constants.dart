import 'package:flutter/foundation.dart';

class AppConstants {
  // API — host depends on where the app runs (see comments in getters).
  static String get baseUrl => '$_apiHost/api';
  static String get socketUrl => _apiHost;

  static const String _hostedUrl = 'https://yabusupermarket.onrender.com';
  static const String _lanHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.121.201.219',
  );

  static String get _apiHost {
    const useLocal = bool.fromEnvironment('USE_LOCAL', defaultValue: false);
    if (!useLocal) {
      return _hostedUrl;
    }
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost:5000';
    }
    const useEmulator =
        bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
    if (defaultTargetPlatform == TargetPlatform.android && useEmulator) {
      return 'http://10.0.2.2:5000';
    }
    // Physical Android / iOS on same Wi‑Fi as this PC
    return 'http://$_lanHost:5000';
  }

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // Timeouts (ms)
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Pagination
  static const int defaultPageSize = 20;

  // Currency
  static const String currency = 'ETB';
}

class AppStrings {
  static const String appName = 'Yabu Supermarket';
  static const String tagline = 'Smart Supermarket Inventory & Sales';

  // Auth
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to Yabu Supermarket';
  static const String emailHint = 'Email address';
  static const String passwordHint = 'Password';
  static const String loginButton = 'Sign In';

  // Errors
  static const String networkError = 'Network error. Check your connection.';
  static const String serverError = 'Server error. Please try again.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String unauthorized = 'You are not authorized for this action.';

  // QR / Barcode
  static const String scanQrTitle = 'Scan Barcode / QR';
  static const String scanQrHint = 'Point camera at product barcode or QR code';
  static const String productFound = 'Product found!';
  static const String productNotFound = 'Product not found.';

  // Sale
  static const String saleRecorded = 'Sale recorded successfully!';
  static const String insufficientStock = 'Insufficient stock';

  // Categories
  static const List<String> categories = [
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

  static const List<String> vehicleTypes = [
    'Piece',
    'Kg',
    'Gram',
    'Liter',
    'Pack',
    'Bottle',
    'Can',
    'Box',
  ];
  static const List<String> paymentMethods = ['cash', 'mobile_money', 'credit'];
}
