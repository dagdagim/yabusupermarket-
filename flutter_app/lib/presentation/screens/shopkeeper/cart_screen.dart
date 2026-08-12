import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String _paymentMethod = 'cash';
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _transferReceiptImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'Confirm Sale',
      message:
          'Record sale of ${cart.length} product type(s) for ${ref.read(cartTotalProvider).toStringAsFixed(0)} ETB?',
      confirmLabel: 'Record Sale',
      confirmColor: AppColors.success,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      final items = cart
          .map((i) => {'productId': i.productId, 'quantity': i.quantitySold})
          .toList();

      final data = await api.recordSale(
        items: items,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        transferReceiptImage:
            _paymentMethod == 'mobile_money' ? _transferReceiptImage : null,
      );

      if (!mounted) return;

      if (data['success'] == true) {
        ref.read(cartProvider.notifier).clearCart();
        _showSuccessDialog(data['sale']);
      } else {
        _showError(data['message'] ?? 'Failed to record sale.');
      }
    } catch (e) {
      if (mounted) _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1400,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() => _transferReceiptImage = base64Encode(bytes));
    } catch (e) {
      if (mounted) _showError('Failed to capture receipt: $e');
    }
  }

  void _showSuccessDialog(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Sale Recorded!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Sora')),
            const SizedBox(height: 8),
            Text(
              sale['saleNumber'] ?? '',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${(sale['totalAmount'] ?? 0).toStringAsFixed(0)} ETB',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                  fontFamily: 'Sora'),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/shopkeeper');
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return LoadingOverlay(
      isLoading: _isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sale Cart'),
          actions: [
            if (cart.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final confirm = await showConfirmDialog(
                    context,
                    title: 'Clear Cart',
                    message: 'Remove all items from cart?',
                    confirmLabel: 'Clear',
                    confirmColor: AppColors.error,
                  );
                  if (confirm == true) ref.read(cartProvider.notifier).clearCart();
                },
                child: const Text('Clear', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: cart.isEmpty
            ? EmptyStateWidget(
                message: 'Cart is empty\nScan a product QR to add items',
                icon: Icons.shopping_cart_outlined,
                actionLabel: 'Scan QR',
                onAction: () => context.go('/shopkeeper/scan'),
              )
            : Column(
                children: [
                  // Cart items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Cart items
                        ...cart.map((item) {
                          return CartItemRow(
                            item: item,
                            maxQty: 999, // ideally fetch from product
                            onRemove: () =>
                                ref.read(cartProvider.notifier).removeItem(item.productId),
                            onQtyChanged: (qty) => ref
                                .read(cartProvider.notifier)
                                .updateQuantity(item.productId, qty),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Payment method
                        const Text('Payment Method',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: 'Sora')),
                        const SizedBox(height: 10),
                        Row(
                          children: AppStrings.paymentMethods.map((method) {
                            final selected = _paymentMethod == method;
                            final label = method
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
                                .join(' ');
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _paymentMethod = method;
                                    if (method != 'mobile_money') {
                                      _transferReceiptImage = null;
                                    }
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primary.withOpacity(0.1)
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: selected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          width: 1.5),
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Sora'),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        if (_paymentMethod == 'mobile_money') ...[
                          _ReceiptCaptureCard(
                            receiptImage: _transferReceiptImage,
                            onCamera: () => _pickReceipt(ImageSource.camera),
                            onGallery: () => _pickReceipt(ImageSource.gallery),
                            onRemove: () =>
                                setState(() => _transferReceiptImage = null),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Notes
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'Add sale notes...',
                            prefixIcon: Icon(Icons.note_outlined),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Order summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              InfoRow(
                                label: 'Items',
                                value: '${cart.fold(0, (s, i) => s + i.quantitySold)} units',
                              ),
                              InfoRow(
                                label: 'Products',
                                value: '${cart.length} types',
                              ),
                              const Divider(height: 16),
                              InfoRow(
                                label: 'Total',
                                value: '${total.toStringAsFixed(0)} ETB',
                                valueColor: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Checkout button
                  Container(
                    padding: EdgeInsets.fromLTRB(
                        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount',
                                style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 14,
                                    color: AppColors.textSecondary)),
                            Text(
                              '${total.toStringAsFixed(0)} ETB',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontFamily: 'Sora'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: cart.isEmpty ? null : _checkout,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Record Sale'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        floatingActionButton: cart.isNotEmpty
            ? FloatingActionButton.small(
                onPressed: () => context.go('/shopkeeper/scan'),
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.qr_code_scanner),
              )
            : null,
      ),
    );
  }
}

class _ReceiptCaptureCard extends StatelessWidget {
  final String? receiptImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  const _ReceiptCaptureCard({
    required this.receiptImage,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (receiptImage != null) {
      try {
        bytes = base64Decode(receiptImage!);
      } catch (_) {
        bytes = null;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_outlined, color: AppColors.info),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Transfer Receipt',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Sora',
                    ),
                  ),
                ),
                if (receiptImage != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                    tooltip: 'Remove receipt',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Center(
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
