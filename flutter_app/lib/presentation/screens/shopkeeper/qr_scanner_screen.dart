import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';

// ─── QR / Barcode Scanner Screen ──────────────────────────────────────────────
class QRScannerScreen extends ConsumerStatefulWidget {
  final bool returnCodeOnly;

  const QRScannerScreen({super.key, this.returnCodeOnly = false});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;
  bool _torchOn = false;
  bool _hasCameraError = false;
  CameraFacing _facing = CameraFacing.front;

  @override
  void initState() {
    super.initState();
    _initController(_facing);
  }

  void _initController(CameraFacing facing) {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: facing,
      torchEnabled: false,
    );
  }

  Future<void> _switchCamera() async {
    final nextFacing = _facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
    setState(() {
      _facing = nextFacing;
      _hasCameraError = false;
    });
    try {
      await _controller.switchCamera();
    } catch (_) {
      _initController(nextFacing);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeFound(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _controller.stop();

    if (widget.returnCodeOnly) {
      if (mounted) Navigator.pop(context, rawCode);
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getProductByQR(rawCode);

      if (!mounted) return;

      if (data['success'] == true) {
        final product = ProductModel.fromJson(data['product']);
        await _showProductBottomSheet(product);
      } else {
        _showError('Product not found for this code: $rawCode');
      }
    } catch (e) {
      if (mounted) _showError('Error looking up barcode. Try again.');
    } finally {
      if (mounted && !widget.returnCodeOnly) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    await _handleBarcodeFound(barcode!.rawValue!);
  }

  Future<void> _showManualEntryDialog() async {
    final textController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode Manually', style: TextStyle(fontFamily: 'Sora', fontSize: 18)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 6001234567011',
            labelText: 'Barcode / SKU',
          ),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = textController.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      await _handleBarcodeFound(code);
    }
  }

  Future<void> _showProductBottomSheet(ProductModel product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductScanResult(product: product),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildCameraFallback(String errorMsg) {
    if (!_hasCameraError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasCameraError = true);
      });
    }
    final manualController = TextEditingController();
    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 54, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              const Text(
                'Barcode Scanner Active',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Sora'),
              ),
              const SizedBox(height: 8),
              Text(
                'Camera stream unavailable in browser preview.\nType or tap a product barcode below to test.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontFamily: 'Sora'),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _switchCamera,
                icon: const Icon(Icons.cameraswitch, size: 18),
                label: Text(_facing == CameraFacing.front ? 'Switch to Back Camera' : 'Switch to Front Webcam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Manual Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: manualController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter barcode (e.g. 6001234567011)',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) _handleBarcodeFound(v.trim());
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColors.accent),
                      onPressed: () {
                        final v = manualController.text.trim();
                        if (v.isNotEmpty) _handleBarcodeFound(v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Quick Test Barcodes:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Sora'),
              ),
              const SizedBox(height: 12),

              // Demo chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _demoChip('6001234567011', '🍌 Bananas'),
                  _demoChip('6001234567042', '🥛 Milk 1L'),
                  _demoChip('5449000000996', '🥤 Coca Cola'),
                  _demoChip('6001234567158', '🌾 Rice 5kg'),
                  _demoChip('6001234567059', '🥚 Eggs 12pk'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoChip(String code, String name) {
    return ActionChip(
      avatar: const Icon(Icons.barcode_reader, size: 14, color: Colors.black87),
      label: Text('$name ($code)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.accent,
      labelStyle: const TextStyle(color: Colors.black),
      onPressed: () => _handleBarcodeFound(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.returnCodeOnly ? 'Scan Product Barcode' : AppStrings.scanQrTitle),
        actions: [
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: _switchCamera,
          ),
          IconButton(
            tooltip: 'Manual Entry',
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _showManualEntryDialog,
          ),
          IconButton(
            icon: Icon(_torchOn ? Icons.flashlight_off : Icons.flashlight_on),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera with Web Fallback
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (ctx, err, child) => _buildCameraFallback(err.toString()),
          ),

          // Overlay (only when camera is live)
          if (!_hasCameraError)
            CustomPaint(
              painter: _ScannerOverlayPainter(),
              child: const SizedBox.expand(),
            ),

          // Bottom Bar (only when camera is live)
          if (!_hasCameraError)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.returnCodeOnly
                              ? 'Point camera at product barcode'
                              : AppStrings.scanQrHint,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Sora'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard_alt_outlined, color: AppColors.accent, size: 18),
                        label: const Text('Type barcode manually',
                            style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 8),
                    const CircularProgressIndicator(color: AppColors.accent),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Scanner Overlay ──────────────────────────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    const scanSize = 240.0;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    // Dark overlay with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner markers
    final cornerPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerLen = 20.0;
    const r = 12.0;

    // Top-left
    canvas.drawLine(Offset(left + r, top), Offset(left + r + cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top + r), Offset(left, top + r + cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(left + scanSize - r - cornerLen, top), Offset(left + scanSize - r, top), cornerPaint);
    canvas.drawLine(Offset(left + scanSize, top + r), Offset(left + scanSize, top + r + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left + r, top + scanSize), Offset(left + r + cornerLen, top + scanSize), cornerPaint);
    canvas.drawLine(Offset(left, top + scanSize - r - cornerLen), Offset(left, top + scanSize - r), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(left + scanSize - r - cornerLen, top + scanSize), Offset(left + scanSize - r, top + scanSize), cornerPaint);
    canvas.drawLine(Offset(left + scanSize, top + scanSize - r - cornerLen), Offset(left + scanSize, top + scanSize - r), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Product Scan Result Sheet ────────────────────────────────────────────────
class _ProductScanResult extends ConsumerStatefulWidget {
  final ProductModel product;

  const _ProductScanResult({required this.product});

  @override
  ConsumerState<_ProductScanResult> createState() => _ProductScanResultState();
}

class _ProductScanResultState extends ConsumerState<_ProductScanResult> {
  int _quantity = 1;

  void _addToCart() {
    final cartNotifier = ref.read(cartProvider.notifier);
    // Add item multiple times based on quantity
    for (int i = 0; i < _quantity; i++) {
      cartNotifier.addItem(widget.product);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.product.name} added to cart'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final total = p.sellingPrice * _quantity;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Product found badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 14),
                    SizedBox(width: 4),
                    Text('Product Found',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Product info
          Text(p.name,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora')),
          const SizedBox(height: 4),
          Text('${p.sku} • ${p.category} • ${p.vehicleType}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          if (p.brand != null) ...[
            const SizedBox(height: 2),
            Text('Brand: ${p.brand}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Price and stock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unit Price',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  Text(
                    '${p.sellingPrice.toStringAsFixed(0)} ETB',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Sora'),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('In Stock',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  Text(
                    '${p.quantity} units',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.isLowStock ? AppColors.warning : AppColors.success,
                        fontFamily: 'Sora'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quantity selector
          if (p.quantity > 0) ...[
            const Text('Quantity',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Sora')),
            const SizedBox(height: 10),
            Row(
              children: [
                _QtyBtn(
                  icon: Icons.remove,
                  enabled: _quantity > 1,
                  onTap: () => setState(() => _quantity--),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('$_quantity',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Sora')),
                ),
                _QtyBtn(
                  icon: Icons.add,
                  enabled: _quantity < p.quantity,
                  onTap: () => setState(() => _quantity++),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      '${total.toStringAsFixed(0)} ETB',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          fontFamily: 'Sora'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Add to cart button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Out of Stock',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.divider,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: enabled ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
        ),
        child: Icon(icon,
            color: enabled ? AppColors.primary : AppColors.textDisabled, size: 20),
      ),
    );
  }
}
