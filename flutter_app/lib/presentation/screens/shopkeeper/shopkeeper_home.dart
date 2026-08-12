import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import '../shared/products_screen.dart';

class ShopkeeperHome extends ConsumerStatefulWidget {
  const ShopkeeperHome({super.key});

  @override
  ConsumerState<ShopkeeperHome> createState() => _ShopkeeperHomeState();
}

class _ShopkeeperHomeState extends ConsumerState<ShopkeeperHome> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cartCount = ref.watch(cartProvider).fold<int>(0, (s, i) => s + i.quantitySold);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${user?.name.split(' ').first ?? 'Shopkeeper'}!'),
            Text(
              user?.shop?.name ?? '',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Cart badge
          badges.Badge(
            badgeContent: Text(
              '$cartCount',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            showBadge: cartCount > 0,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => context.push('/shopkeeper/cart'),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.accentLight,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'S',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            onPressed: () => context.push('/shopkeeper/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _ShopkeeperDashboard(),
          const ProductsScreen(isShopkeeper: true),
          _MySalesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/shopkeeper/scan'),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
        label: const Text('Scan Code',
            style: TextStyle(color: Colors.black, fontFamily: 'Sora', fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2,
              label: 'Products',
              selected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
            const SizedBox(width: 72), // FAB space
            _NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'My Sales',
              selected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
            _NavItem(
              icon: Icons.shopping_cart_outlined,
              activeIcon: Icons.shopping_cart,
              label: 'Cart',
              selected: false,
              badge: cartCount > 0 ? '$cartCount' : null,
              onTap: () => context.push('/shopkeeper/cart'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badges.Badge(
              showBadge: badge != null,
              badgeContent: Text(badge ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
              child: Icon(
                selected ? activeIcon : icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Sora',
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopkeeperDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final api = ref.watch(apiServiceProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(lowStockProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick action banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ready to sell?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora')),
                        const SizedBox(height: 4),
                        Text(
                          'Scan a product QR code to start',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/shopkeeper/scan'),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Today's quick stats for shopkeeper
            FutureBuilder<Map<String, dynamic>>(
              future: api.getSales(page: 1, limit: 1),
              builder: (ctx, snap) {
                return const SizedBox.shrink();
              },
            ),

            const SectionHeader(title: 'Low Stock Alerts'),
            Consumer(
              builder: (context, ref, _) {
                final lowStock = ref.watch(lowStockProvider);
                return lowStock.when(
                  data: (products) {
                    final myShopProducts = products
                        .where((p) => p.shop?.id == user?.shop?.id)
                        .toList();
                    return myShopProducts.isEmpty
                        ? const EmptyStateWidget(
                            message: 'All products are well stocked!',
                            icon: Icons.check_circle_outline)
                        : Column(
                            children: myShopProducts
                                .take(5)
                                .map((p) => LowStockItem(product: p))
                                .toList(),
                          );
                  },
                  loading: () => const ShimmerList(itemCount: 3),
                  error: (e, _) => ErrorCard(message: e.toString()),
                );
              },
            ),

            const SizedBox(height: 20),
            SectionHeader(
              title: 'Recent Sales',
              actionLabel: 'View All',
              onAction: () {},
            ),
            _RecentSalesWidget(api: api),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Yabu Supermarket System',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      fontFamily: 'Sora',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Created by ${AppStrings.companyName} • Developed by ${AppStrings.developerName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _RecentSalesWidget extends StatelessWidget {
  final ApiService api;
  const _RecentSalesWidget({required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: api.getSales(page: 1, limit: 5),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList(itemCount: 3);
        }
        if (snap.hasError) {
          return ErrorCard(message: snap.error.toString());
        }
        final sales = (snap.data?['data'] as List<dynamic>? ?? [])
            .map((s) => SaleModel.fromJson(s))
            .toList();
        if (sales.isEmpty) {
          return const EmptyStateWidget(
              message: 'No sales today yet', icon: Icons.receipt_long_outlined);
        }
        return Column(
          children: sales.map((s) => SaleCard(sale: s)).toList(),
        );
      },
    );
  }
}

class _MySalesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MySalesTab> createState() => _MySalesTabState();
}

class _MySalesTabState extends ConsumerState<_MySalesTab> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getSales(page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _sales = (data['data'] as List<dynamic>? ?? [])
            .map((s) => SaleModel.fromJson(s))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(16), child: ShimmerList());
    }
    if (_sales.isEmpty) {
      return const EmptyStateWidget(
        message: 'No sales recorded yet',
        icon: Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sales.length,
        itemBuilder: (_, i) => SaleCard(sale: _sales[i]),
      ),
    );
  }
}
