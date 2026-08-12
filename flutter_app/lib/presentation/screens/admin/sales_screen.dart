import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class SalesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const SalesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final List<SaleModel> _sales = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 20;

  String? _selectedShopId;
  DateTimeRange? _selectedDateRange;
  final _scrollController = ScrollController();
  final Set<String> _expandedSaleIds = {};
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadSales();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreSales();
    }
  }

  Future<void> _loadSales({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _page = 1;
        _sales.clear();
        _hasMore = true;
        _expandedSaleIds.clear();
      });
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      String? startDate;
      String? endDate;

      if (_selectedDateRange != null) {
        startDate = _selectedDateRange!.start.toIso8601String();
        endDate = _selectedDateRange!.end.toIso8601String();
      }

      final data = await api.getSales(
        page: _page,
        limit: _limit,
        shop: _selectedShopId,
        startDate: startDate,
        endDate: endDate,
      );

      final fetched = (data['data'] as List<dynamic>? ?? [])
          .map((s) => SaleModel.fromJson(s))
          .toList();

      if (!mounted) return;
      setState(() {
        _sales.addAll(fetched);
        _hasMore = fetched.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sales: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreSales() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final api = ref.read(apiServiceProvider);
      String? startDate;
      String? endDate;

      if (_selectedDateRange != null) {
        startDate = _selectedDateRange!.start.toIso8601String();
        endDate = _selectedDateRange!.end.toIso8601String();
      }

      final data = await api.getSales(
        page: _page + 1,
        limit: _limit,
        shop: _selectedShopId,
        startDate: startDate,
        endDate: endDate,
      );

      final fetched = (data['data'] as List<dynamic>? ?? [])
          .map((s) => SaleModel.fromJson(s))
          .toList();

      if (!mounted) return;
      setState(() {
        _page++;
        _sales.addAll(fetched);
        _hasMore = fetched.length == _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more sales: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _toggleExpand(String saleId) {
    setState(() {
      if (_expandedSaleIds.contains(saleId)) {
        _expandedSaleIds.remove(saleId);
      } else {
        _expandedSaleIds.add(saleId);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _loadSales(reset: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedShopId = null;
      _selectedDateRange = null;
    });
    _loadSales(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Sales Transactions'),
              actions: [
                if (_selectedShopId != null || _selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: _clearFilters,
                    tooltip: 'Clear Filters',
                  ),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _pickDateRange,
                  tooltip: 'Filter by Date',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Shop Selector Bar & Actions (if mounted as tab without AppBar)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.showAppBar) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sales Transactions',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Sora'),
                      ),
                      Row(
                        children: [
                          if (_selectedShopId != null || _selectedDateRange != null)
                            IconButton(
                              icon: const Icon(Icons.filter_alt_off, size: 20),
                              onPressed: _clearFilters,
                              tooltip: 'Clear Filters',
                            ),
                          IconButton(
                            icon: const Icon(Icons.date_range, size: 20),
                            onPressed: _pickDateRange,
                            tooltip: 'Filter by Date',
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Date Range Indicator
                if (_selectedDateRange != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${DateFormat('d MMM').format(_selectedDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_selectedDateRange!.end)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedDateRange = null);
                            _loadSales(reset: true);
                          },
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                // Shops horizontal Selector
                shopsAsync.when(
                  data: (shops) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Shops'),
                            selected: _selectedShopId == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedShopId = null);
                                _loadSales(reset: true);
                              }
                            },
                            selectedColor: AppColors.primary.withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: _selectedShopId == null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: _selectedShopId == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...shops.map((shop) {
                            final isSelected = _selectedShopId == shop.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(shop.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedShopId = shop.id);
                                    _loadSales(reset: true);
                                  }
                                },
                                selectedColor: AppColors.primary.withOpacity(0.12),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Total Stats summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_sales.length} transactions',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                if (_isLoading && _sales.isEmpty)
                  const Text(
                    'Loading...',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: _isLoading && _sales.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(itemCount: 6),
                  )
                : _sales.isEmpty
                    ? EmptyStateWidget(
                        message: 'No sales recorded matching criteria',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'Refresh',
                        onAction: () => _loadSales(reset: true),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadSales(reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _sales.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _sales.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final sale = _sales[i];
                            final isExpanded =
                                _expandedSaleIds.contains(sale.id);

                            return _SalesCard(
                              sale: sale,
                              isExpanded: isExpanded,
                              onTap: () => _toggleExpand(sale.id),
                              fmt: _fmt,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  final SaleModel sale;
  final bool isExpanded;
  final VoidCallback onTap;
  final NumberFormat fmt;

  const _SalesCard({
    required this.sale,
    required this.isExpanded,
    required this.onTap,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted = _fmtDate(sale.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header / Tap Area
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.saleNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: 'Sora',
                                color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormatted,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${fmt.format(sale.totalAmount)} ETB',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.success,
                                fontFamily: 'Sora'),
                          ),
                          const SizedBox(height: 2),
                          // Profit details for admin
                          Text(
                            'Profit: +${fmt.format(sale.totalProfit)} ETB',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.store_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        sale.shopName,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(Icons.person_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        sale.shopkeeperName,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sale.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isExpanded ? 'Hide Details' : 'View Sold Products',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable Sold Items Table
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              color: AppColors.surfaceVariant.withOpacity(0.2),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sold Products',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: 'Sora',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sale.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, idx) {
                      final item = sale.items[idx];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.productSku != null)
                                  Text(
                                    item.productSku!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.quantitySold} x ${fmt.format(item.unitPrice)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${fmt.format(item.totalPrice)} ETB',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (sale.paymentMethod == 'mobile_money' &&
                      sale.transferReceiptImage != null &&
                      sale.transferReceiptImage!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Transfer Receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Sora',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReceiptThumbnail(imageBase64: sale.transferReceiptImage!),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today at ${DateFormat('HH:mm').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day &&
        dt.month == yesterday.month &&
        dt.year == yesterday.year) {
      return 'Yesterday at ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('EEE, d MMM yyyy, HH:mm').format(dt);
  }
}

class _ReceiptThumbnail extends StatelessWidget {
  final String imageBase64;

  const _ReceiptThumbnail({required this.imageBase64});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(imageBase64);
      return InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return const Text(
        'Receipt image could not be displayed',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
    }
  }
}
