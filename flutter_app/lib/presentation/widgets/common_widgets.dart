import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

// ─── Error Card ───────────────────────────────────────────────────────────────
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Sora'),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer List ─────────────────────────────────────────────────────────────
class ShimmerList extends StatelessWidget {
  final int itemCount;
  const ShimmerList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          itemCount,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Low Stock Item ───────────────────────────────────────────────────────────
class LowStockItem extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const LowStockItem({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFamily: 'Sora'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(product.shop?.name ?? '',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.quantity == 0
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${product.quantity} left',
                    style: TextStyle(
                      color: product.quantity == 0 ? AppColors.error : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

Widget buildProductImageWidget(
  String? image, {
  double size = 48,
  double borderRadius = 12,
  IconData fallbackIcon = Icons.shopping_bag_outlined,
}) {
  if (image != null && image.trim().isNotEmpty) {
    final img = image.trim();
    if (img.startsWith('data:image') || img.length > 250) {
      try {
        final base64Clean = img.contains(',') ? img.split(',').last : img;
        final bytes = base64Decode(base64Clean);
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    } else if (img.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackBox(size, borderRadius, fallbackIcon),
        ),
      );
    }
  }
  return _fallbackBox(size, borderRadius, fallbackIcon);
}

Widget _fallbackBox(double size, double borderRadius, IconData icon) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Icon(icon, color: AppColors.primary, size: size * 0.5),
  );
}

// ─── Product Card ─────────────────────────────────────────────────────────────
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final bool showCartButton;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.showCartButton = false,
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
              // Product thumbnail / image
              buildProductImageWidget(product.image, size: 52, borderRadius: 12),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: 'Sora'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${product.sku} • ${product.brand ?? product.vehicleType}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Sora'),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${product.sellingPrice.toStringAsFixed(0)} ETB',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 14,
                              fontFamily: 'Sora'),
                        ),
                        const SizedBox(width: 8),
                        _StockBadge(quantity: product.quantity, isLow: product.isLowStock),
                      ],
                    ),
                  ],
                ),
              ),
              if (showCartButton && product.quantity > 0)
                IconButton(
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  color: AppColors.primary,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  ),
                ),
            ],
          ),
        ),
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
    final color = quantity == 0
        ? AppColors.error
        : isLow
            ? AppColors.warning
            : AppColors.success;
    final bg = color.withOpacity(0.1);
    final label = quantity == 0 ? 'Out of stock' : 'Qty: $quantity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Sora')),
    );
  }
}

// ─── Sale Card ────────────────────────────────────────────────────────────────
class SaleCard extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback? onTap;

  const SaleCard({super.key, required this.sale, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = _fmtDate(sale.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sale.saleNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          fontFamily: 'Sora',
                          color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${sale.totalAmount.toStringAsFixed(0)} ETB',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.success,
                          fontFamily: 'Sora')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.store_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sale.shopName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.person_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      sale.shopkeeperName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${sale.items.length} item(s) • ${sale.paymentMethod}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(fmt,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'completed': return AppColors.success;
      case 'verified': return AppColors.info;
      case 'pending': return AppColors.warning;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: _color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontFamily: 'Sora'),
      ),
    );
  }
}

// ─── Cart Item Row ────────────────────────────────────────────────────────────
class CartItemRow extends StatelessWidget {
  final SaleItemModel item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;
  final int maxQty;

  const CartItemRow({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
    required this.maxQty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFamily: 'Sora'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${item.unitPrice.toStringAsFixed(0)} ETB each',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Qty stepper
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () => onQtyChanged(item.quantitySold - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${item.quantitySold}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Sora')),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: item.quantitySold < maxQty
                      ? () => onQtyChanged(item.quantitySold + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.computedTotal.toStringAsFixed(0)} ETB',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.divider,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? AppColors.primary : AppColors.textDisabled),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora',
                  color: AppColors.textPrimary)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontFamily: 'Sora',
                      fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

// ─── Confirm Dialog ───────────────────────────────────────────────────────────
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = AppColors.primary,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontFamily: 'Sora')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Sora')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

// ─── Loading Overlay ──────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Processing...', style: TextStyle(fontFamily: 'Sora')),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Sora')),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'Sora',
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}
