import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Try refresh
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the original request
              final opts = Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              );
              final token = await _storage.read(key: AppConstants.accessTokenKey);
              opts.headers!['Authorization'] = 'Bearer $token';
              final response = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: opts,
              );
              handler.resolve(response);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
    _initialized = true;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConstants.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.data['success'] == true) {
        await _storage.write(
          key: AppConstants.accessTokenKey,
          value: response.data['accessToken'],
        );
        await _storage.write(
          key: AppConstants.refreshTokenKey,
          value: response.data['refreshToken'],
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // AUTH
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return res.data;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final res = await _dio.put('/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword});
    return res.data;
  }

  // PRODUCTS
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? vehicleType,
    String? shop,
    bool lowStock = false,
  }) async {
    final res = await _dio.get('/products', queryParameters: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null) 'category': category,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (shop != null) 'shop': shop,
      if (lowStock) 'lowStock': 'true',
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getProduct(String id) async {
    final res = await _dio.get('/products/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> getProductByQR(String qrData) async {
    final res = await _dio.get('/products/qr/$qrData');
    return res.data;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _dio.post('/products', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/products/$id', data: data);
    return res.data;
  }

  Future<void> deleteProduct(String id) async {
    await _dio.delete('/products/$id');
  }

  Future<Map<String, dynamic>> getLowStockProducts() async {
    final res = await _dio.get('/products/low-stock');
    return res.data;
  }

  // SALES
  Future<Map<String, dynamic>> recordSale({
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'cash',
    String? notes,
    String? transferReceiptImage,
  }) async {
    final res = await _dio.post('/sales', data: {
      'items': items,
      'paymentMethod': paymentMethod,
      if (notes != null) 'notes': notes,
      if (transferReceiptImage != null) 'transferReceiptImage': transferReceiptImage,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getSales({
    int page = 1,
    int limit = 20,
    String? shop,
    String? startDate,
    String? endDate,
  }) async {
    final res = await _dio.get('/sales', queryParameters: {
      'page': page,
      'limit': limit,
      if (shop != null) 'shop': shop,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final res = await _dio.get('/sales/summary/today');
    return res.data;
  }

  Future<Map<String, dynamic>> getSalesAnalytics({String period = 'weekly', String? shop}) async {
    final res = await _dio.get('/sales/analytics', queryParameters: {
      'period': period,
      if (shop != null) 'shop': shop,
    });
    return res.data;
  }

  // SHIPMENTS
  Future<Map<String, dynamic>> createShipment(Map<String, dynamic> data) async {
    final res = await _dio.post('/shipments', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getShipments({String? status}) async {
    final res = await _dio.get('/shipments', queryParameters: {
      if (status != null) 'status': status,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> verifyShipment(String shipmentId) async {
    final res = await _dio.put('/shipments/$shipmentId/verify');
    return res.data;
  }

  // USERS & SHOPS
  Future<Map<String, dynamic>> getShops() async {
    final res = await _dio.get('/users/shops');
    return res.data;
  }

  Future<Map<String, dynamic>> createShop(Map<String, dynamic> data) async {
    final res = await _dio.post('/users/shops', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getUsers({String? role, String? shop}) async {
    final res = await _dio.get('/users', queryParameters: {
      if (role != null) 'role': role,
      if (shop != null) 'shop': shop,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final res = await _dio.post('/users', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> updateUser(
      String userId, Map<String, dynamic> data) async {
    final res = await _dio.put('/users/$userId', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> toggleUserStatus(String userId) async {
    final res = await _dio.put('/users/$userId/toggle-status');
    return res.data;
  }

  // RECONCILIATION
  Future<Map<String, dynamic>> generateReconciliation(String shopId, String date) async {
    final res = await _dio.post('/reconciliation/generate', data: {'shopId': shopId, 'date': date});
    return res.data;
  }

  Future<Map<String, dynamic>> getReconciliations({String? shop, String? status}) async {
    final res = await _dio.get('/reconciliation', queryParameters: {
      if (shop != null) 'shop': shop,
      if (status != null) 'status': status,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> updateReconciliation(
      String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/reconciliation/$id', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getTodayReconciliation() async {
    final res = await _dio.get('/reconciliation/today');
    return res.data;
  }

  Future<void> deleteReconciliation(String id) async {
    try {
      await _dio.delete('/reconciliation/$id');
    } catch (_) {
      await _dio.post('/reconciliation/$id/delete');
    }
  }

  // REPORTS
  Future<Map<String, dynamic>> getReport({String period = 'daily', String? shop}) async {
    final res = await _dio.get('/reports', queryParameters: {
      'period': period,
      if (shop != null) 'shop': shop,
    });
    return res.data;
  }

  String getReportExportUrl(String type, {String period = 'daily'}) {
    return '${AppConstants.baseUrl}/reports/export/$type?period=$period';
  }
}
