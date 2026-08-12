import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../data/datasources/api_service.dart';
// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Expire/clear session on app restart so user returns to login screen
    await _clearSession();
  }

  Future<void> _refreshUser() async {
    try {
      final data = await _api.getMe();
      if (data['success'] == true) {
        final user = UserModel.fromJson(data['user']);
        await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
        state = state.copyWith(user: user, isAuthenticated: true);
      }
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email, password);
      if (data['success'] == true) {
        await _storage.write(
            key: AppConstants.accessTokenKey, value: data['accessToken']);
        await _storage.write(
            key: AppConstants.refreshTokenKey, value: data['refreshToken']);

        final user = UserModel.fromJson(data['user']);
        await _storage.write(
            key: AppConstants.userKey, value: jsonEncode(user.toJson()));

        state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: data['message'] ?? 'Login failed');
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      state = state.copyWith(
        isLoading: false,
        error: message ??
            (e.response?.statusCode == 401
                ? 'Invalid email or password.'
                : 'Network error. Check your connection.'),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error. Check your connection.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _api.logout();
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _storage.deleteAll();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);
}

// Providers
final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  api.init();
  return api;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(secureStorageProvider),
  );
});

// Products provider
final productsProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, params) async {
    final api = ref.watch(apiServiceProvider);
    return api.getProducts(
      page: params['page'] ?? 1,
      search: params['search'],
      category: params['category'],
      vehicleType: params['vehicleType'],
      lowStock: params['lowStock'] ?? false,
    );
  },
);

// Dashboard summary provider
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getTodaySummary();
  return DashboardSummary.fromJson(data);
});

// Low stock provider
final lowStockProvider = FutureProvider<List<ProductModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getLowStockProducts();
  return (data['products'] as List<dynamic>? ?? [])
      .map((p) => ProductModel.fromJson(p))
      .toList();
});

final pendingShipmentsProvider = FutureProvider<List<ShipmentModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getShipments(status: 'pending');
  return (data['data'] as List<dynamic>? ?? [])
      .map((s) => ShipmentModel.fromJson(s))
      .toList();
});

// Sales cart state
class CartNotifier extends StateNotifier<List<SaleItemModel>> {
  CartNotifier() : super([]);

  void addItem(ProductModel product) {
    final existingIndex = state.indexWhere((i) => i.productId == product.id);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      if (existing.quantitySold < product.quantity) {
        final updated = List<SaleItemModel>.from(state);
        updated[existingIndex] = SaleItemModel(
          productId: existing.productId,
          productName: existing.productName,
          productSku: existing.productSku,
          quantitySold: existing.quantitySold + 1,
          unitPrice: existing.unitPrice,
          totalPrice: existing.unitPrice * (existing.quantitySold + 1),
        );
        state = updated;
      }
    } else {
      state = [...state, SaleItemModel.fromProduct(product, 1)];
    }
  }

  void removeItem(String productId) {
    state = state.where((i) => i.productId != productId).toList();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    state = state.map((i) {
      if (i.productId == productId) {
        return SaleItemModel(
          productId: i.productId,
          productName: i.productName,
          productSku: i.productSku,
          quantitySold: quantity,
          unitPrice: i.unitPrice,
          totalPrice: i.unitPrice * quantity,
        );
      }
      return i;
    }).toList();
  }

  void clearCart() => state = [];

  double get total => state.fold(0, (sum, item) => sum + item.computedTotal);
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantitySold);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<SaleItemModel>>(
  (ref) => CartNotifier(),
);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.computedTotal);
});

// Shops provider
final shopsProvider = FutureProvider<List<ShopModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getShops();
  return (data['shops'] as List<dynamic>? ?? [])
      .map((s) => ShopModel.fromJson(s))
      .toList();
});
