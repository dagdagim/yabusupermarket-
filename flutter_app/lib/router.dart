import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/admin/admin_dashboard.dart';
import 'presentation/screens/admin/reconciliation_screen.dart';
import 'presentation/screens/admin/shipments_screen.dart';
import 'presentation/screens/admin/users_screen.dart';
import 'presentation/screens/shopkeeper/shopkeeper_home.dart';
import 'presentation/screens/shopkeeper/qr_scanner_screen.dart';
import 'presentation/screens/shopkeeper/cart_screen.dart';
import 'presentation/screens/shared/products_screen.dart';
import 'presentation/screens/shared/product_detail_screen.dart';
// Import for LowStockItem and StatusBadge used in placeholder screens
import 'presentation/widgets/common_widgets.dart';
import 'core/theme/app_theme.dart';
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isAdmin = authState.user?.isAdmin ?? false;
      final isShopkeeper = authState.user?.isShopkeeper ?? false;

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) {
        return isAdmin ? '/admin' : '/shopkeeper';
      }

      // Role guard
      if (isLoggedIn && isShopkeeper && state.matchedLocation.startsWith('/admin')) {
        return '/shopkeeper';
      }

      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboard(),
        routes: [
          GoRoute(
            path: 'products',
            builder: (_, __) => const ProductsScreen(),
          ),
          GoRoute(
            path: 'products/add',
            builder: (_, __) => const ProductsScreen(openAddOnMount: true),
          ),
          GoRoute(
            path: 'products/:id',
            builder: (ctx, state) => ProductDetailScreen(
              productId: state.pathParameters['id']!,
              isAdmin: true,
            ),
          ),
          GoRoute(
            path: 'reconciliation',
            builder: (_, __) => const ReconciliationScreen(),
          ),
          GoRoute(
            path: 'shipments',
            builder: (_, __) => const ShipmentsScreen(),
          ),
          GoRoute(
            path: 'low-stock',
            builder: (_, __) => const _LowStockScreen(),
          ),
          GoRoute(
            path: 'users',
            builder: (_, __) => const UsersScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const _ProfileScreen(),
          ),
        ],
      ),

      // Shopkeeper routes
      GoRoute(
        path: '/shopkeeper',
        builder: (_, __) => const ShopkeeperHome(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (_, __) => const QRScannerScreen(),
          ),
          GoRoute(
            path: 'cart',
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: 'products/:id',
            builder: (ctx, state) => ProductDetailScreen(
              productId: state.pathParameters['id']!,
              allowAddToCart: true,
            ),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const _ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

// ─── Placeholder screens (implement fully in production) ──────────────────────

class _LowStockScreen extends ConsumerWidget {
  const _LowStockScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock Alerts')),
      body: lowStock.when(
        data: (products) => products.isEmpty
            ? const Center(child: Text('All products are well stocked!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (_, i) => LowStockItem(
                  product: products[i],
                  onTap: () =>
                      context.push('/admin/products/${products[i].id}'),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _UsersScreen extends StatelessWidget {
  const _UsersScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Manage Users')),
        body: const Center(child: Text('Users management screen')),
      );
}

class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Sora')),
            Text(user?.email ?? '',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            StatusBadge(status: user?.role ?? ''),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: Text(user?.shop?.name ?? 'All Shops'),
              subtitle: Text(user?.shop?.location ?? 'Admin Access'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
