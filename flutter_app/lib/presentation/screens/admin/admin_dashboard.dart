import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import 'reconciliation_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';
import '../shared/products_screen.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedTab = 0;

  final List<Widget> _tabs = [];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yabu Supermarket Admin'),
            Text(
              DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/admin/low-stock'),
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentLight,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'A',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            onPressed: () => context.push('/admin/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _DashboardTab(),
          _ProductsTab(),
          _SalesTab(),
          _ReconciliationTab(),
          _ReportsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Products'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Sales'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Cash'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final lowStock = ref.watch(lowStockProvider);
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(lowStockProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text("Today's Overview",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Summary cards
            summary.when(
              data: (data) => Column(children: [
                Row(children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Revenue',
                      value: '${fmt.format(data.totalRevenue)} ETB',
                      icon: Icons.trending_up,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Profit',
                      value: '${fmt.format(data.totalProfit)} ETB',
                      icon: Icons.savings_outlined,
                      color: AppColors.info,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Transactions',
                      value: '${data.totalTransactions}',
                      icon: Icons.receipt_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Items Sold',
                      value: '${data.totalItemsSold}',
                      icon: Icons.shopping_cart_outlined,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ]),
                if (data.shopBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Shop Comparison',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...data.shopBreakdown.map((s) => _ShopCard(shop: s, fmt: fmt)),
                ],
              ]),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorCard(message: e.toString()),
            ),

            const SizedBox(height: 20),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ref.watch(pendingShipmentsProvider).when(
                  data: (shipments) => _QuickActionCard(
                    title: 'Shipped Products',
                    subtitle:
                        '${shipments.length} pending arrival verification',
                    icon: Icons.local_shipping_outlined,
                    count: shipments.length,
                    onTap: () => context.push('/admin/shipments'),
                  ),
                  loading: () => _QuickActionCard(
                    title: 'Shipped Products',
                    subtitle: 'Loading shipment status',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => context.push('/admin/shipments'),
                  ),
                  error: (_, __) => _QuickActionCard(
                    title: 'Shipped Products',
                    subtitle: 'Review shipment tracking',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => context.push('/admin/shipments'),
                  ),
                ),

            // Low stock alerts
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Low Stock Alerts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                lowStock.when(
                  data: (products) => products.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                          child: Text('${products.length}',
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            lowStock.when(
              data: (products) => products.isEmpty
                  ? const EmptyStateWidget(message: 'No low stock products', icon: Icons.check_circle_outline)
                  : Column(
                      children: products
                          .take(5)
                          .map((p) => LowStockItem(product: p))
                          .toList(),
                    ),
              loading: () => const ShimmerList(),
              error: (e, _) => ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Sora')),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Sora'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopSummary shop;
  final NumberFormat fmt;

  const _ShopCard({required this.shop, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.shopName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${shop.totalTransactions} transactions',
                      style:
                          const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(shop.totalRevenue)} ETB',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        fontSize: 14)),
                Text('Profit: ${fmt.format(shop.totalProfit)} ETB',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? count;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Sora',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder tabs - fully implement as separate files in production
class _ProductsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductsScreen(showAppBar: false);
  }
}

class _SalesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SalesScreen(showAppBar: false);
  }
}

class _ReconciliationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ReconciliationScreen(showAppBar: false);
  }
}

class _ReportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ReportsScreen(showAppBar: false);
  }
}
