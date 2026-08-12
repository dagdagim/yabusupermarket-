import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  final bool isAdmin;
  final bool allowAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.isAdmin = false,
    this.allowAddToCart = false,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductModel? _product;
  bool _loading = true;
  String? _error;
  int _cartQty = 1;

  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('d MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).getProduct(widget.productId);
      if (data['success'] == true && data['product'] != null) {
        setState(() {
          _product = ProductModel.fromJson(data['product']);
          _loading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'Product not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load product';
        _loading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Product',
      message:
          'Remove "${_product!.name}" from inventory? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiServiceProvider).deleteProduct(widget.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['message']?.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? 'Delete failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editProductPrices() async {
    if (!widget.isAdmin) return;
    final p = _product;
    if (p == null) return;

    final purchaseController =
        TextEditingController(text: p.purchasePrice.toStringAsFixed(2));
    final sellingController =
        TextEditingController(text: p.sellingPrice.toStringAsFixed(2));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Product Prices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: purchaseController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Purchase Price',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sellingController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final purchase =
                  double.tryParse(purchaseController.text.trim()) ?? -1;
              final selling =
                  double.tryParse(sellingController.text.trim()) ?? -1;

              if (purchase < 0 || selling < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prices must be zero or higher'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              try {
                final data = await ref.read(apiServiceProvider).updateProduct(
                  widget.productId,
                  {
                    'purchasePrice': purchase,
                    'sellingPrice': selling,
                  },
                );
                if (data['success'] == true && ctx.mounted) {
                  Navigator.pop(ctx, true);
                }
              } on DioException catch (e) {
                final msg = (e.response?.data as Map?)?['message']?.toString();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg ?? 'Price update failed'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Price update failed: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    purchaseController.dispose();
    sellingController.dispose();

    if (saved == true) {
      await _loadProduct();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product prices updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _addToCart() {
    final p = _product!;
    final notifier = ref.read(cartProvider.notifier);
    for (var i = 0; i < _cartQty; i++) {
      notifier.addItem(p);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_cartQty × ${p.name} added to cart'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (widget.isAdmin && _product != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editProductPrices,
              tooltip: 'Edit prices',
            ),
          if (widget.isAdmin && _product != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteProduct,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProduct,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    if (!widget.allowAddToCart || _product == null || _product!.quantity <= 0) {
      return null;
    }
    final p = _product!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _QtyStepper(
              value: _cartQty,
              max: p.quantity,
              onChanged: (v) => setState(() => _cartQty = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'Add — ${(p.sellingPrice * _cartQty).toStringAsFixed(0)} ${AppConstants.currency}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyStateWidget(
        message: _error!,
        icon: Icons.error_outline,
        actionLabel: 'Retry',
        onAction: _loadProduct,
      );
    }

    final p = _product!;
    return RefreshIndicator(
      onRefresh: _loadProduct,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _HeaderCard(product: p),
          const SizedBox(height: 16),
          _Section(
            title: 'Pricing',
            child: Column(
              children: [
                if (widget.isAdmin)
                  _DetailRow(
                    label: 'Purchase price',
                    value: '${_fmt.format(p.purchasePrice)} ${AppConstants.currency}',
                  ),
                _DetailRow(
                  label: 'Selling price',
                  value: '${_fmt.format(p.sellingPrice)} ${AppConstants.currency}',
                  valueStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if (widget.isAdmin)
                  _DetailRow(
                    label: 'Profit margin',
                    value: '${p.profitMargin.toStringAsFixed(1)}%',
                    valueStyle: TextStyle(
                      color: p.profitMargin >= 0
                          ? AppColors.success
                          : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Inventory',
            child: Column(
              children: [
                _DetailRow(
                  label: 'Quantity in stock',
                  value: '${p.quantity} units',
                ),
                _DetailRow(
                  label: 'Low stock alert at',
                  value: '${p.lowStockThreshold} units',
                ),
                const SizedBox(height: 8),
                _StockBadge(quantity: p.quantity, isLow: p.isLowStock),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Classification',
            child: Column(
              children: [
                _DetailRow(label: 'SKU', value: p.sku),
                if (p.barcode != null && p.barcode!.isNotEmpty)
                  _DetailRow(label: 'Barcode', value: p.barcode!),
                _DetailRow(label: 'Category', value: p.category),
                _DetailRow(label: 'Unit / Packaging', value: p.vehicleType),
                if (p.brand != null && p.brand!.isNotEmpty)
                  _DetailRow(label: 'Brand', value: p.brand!),
              ],
            ),
          ),
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Description',
              child: Text(
                p.description!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                  fontFamily: 'Sora',
                ),
              ),
            ),
          ],
          if (p.shop != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Shop',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.shop!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            fontFamily: 'Sora',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p.shop!.location,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontFamily: 'Sora',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (p.shop!.phone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.shop!.phone!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (p.qrCode != null && p.qrCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'QR Code',
              child: Center(
                child: Column(
                  children: [
                    _QrImage(dataUrl: p.qrCode!),
                    const SizedBox(height: 8),
                    Text(
                      'Scan to identify this product',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.9),
                        fontSize: 12,
                        fontFamily: 'Sora',
                      ),
                    ),
                    if (p.qrCodeData != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'ID: ${p.qrCodeData}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textDisabled,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            title: 'Record',
            child: _DetailRow(
              label: 'Added on',
              value: _dateFmt.format(p.createdAt.toLocal()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ProductModel product;

  const _HeaderCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildProductImageWidget(product.image, size: 64, borderRadius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Sora',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ChipLabel(text: product.category),
                      _ChipLabel(
                        text: product.vehicleType,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const _ChipLabel({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
          fontFamily: 'Sora',
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'Sora',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Sora',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int quantity;
  final bool isLow;

  const _StockBadge({required this.quantity, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final label = quantity == 0
        ? 'Out of stock'
        : isLow
            ? 'Low stock'
            : 'In stock';
    final color = quantity == 0
        ? AppColors.error
        : isLow
            ? AppColors.warning
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quantity == 0
                ? Icons.remove_circle_outline
                : isLow
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontFamily: 'Sora',
            ),
          ),
        ],
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  final String dataUrl;

  const _QrImage({required this.dataUrl});

  @override
  Widget build(BuildContext context) {
    try {
      final base64Str = dataUrl.contains(',')
          ? dataUrl.split(',').last
          : dataUrl;
      final bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return const Icon(Icons.qr_code_2, size: 120, color: AppColors.textDisabled);
    }
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              fontFamily: 'Sora',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
