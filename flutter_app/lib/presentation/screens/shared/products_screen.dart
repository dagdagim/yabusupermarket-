import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import '../shopkeeper/qr_scanner_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final bool isShopkeeper;
  /// When true (admin dashboard tab), hides nested AppBar and shows FAB to add.
  final bool showAppBar;
  final bool openAddOnMount;
  const ProductsScreen({
    super.key,
    this.isShopkeeper = false,
    this.showAppBar = true,
    this.openAddOnMount = false,
  });

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedVehicleType;
  bool _showLowStock = false;
  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.openAddOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddProduct());
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadProducts(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool loadMore = false, bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() { _page = 1; _products = []; _hasMore = true; });
    }
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getProducts(
        page: loadMore ? _page + 1 : _page,
        search: _searchController.text.trim(),
        category: _selectedCategory,
        vehicleType: _selectedVehicleType,
        lowStock: _showLowStock,
      );
      final newProducts = (data['data'] as List<dynamic>? ?? [])
          .map((p) => ProductModel.fromJson(p))
          .toList();
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _products.addAll(newProducts);
          _page++;
        } else {
          _products = newProducts;
        }
        _hasMore = newProducts.length == AppConstants.defaultPageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _openAddProduct({String? initialBarcode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddProductSheet(
        initialBarcode: initialBarcode,
        onSaved: () {
          Navigator.pop(ctx);
          _loadProducts(reset: true);
        },
      ),
    );
  }

  Future<void> _scanAndAddProduct() async {
    final scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(returnCodeOnly: true),
      ),
    );

    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      try {
        final api = ref.read(apiServiceProvider);
        final res = await api.getProductByQR(scannedBarcode);
        if (res['success'] == true && res['product'] != null) {
          final product = ProductModel.fromJson(res['product']);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product exists: ${product.name} (${product.sku})'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  final isAdmin = !widget.isShopkeeper;
                  context.push(
                    isAdmin
                        ? '/admin/products/${product.id}'
                        : '/shopkeeper/products/${product.id}',
                  );
                },
              ),
            ),
          );
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      _openAddProduct(initialBarcode: scannedBarcode);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedCategory: _selectedCategory,
        selectedVehicleType: _selectedVehicleType,
        showLowStock: _showLowStock,
        onApply: (category, vehicleType, lowStock) {
          setState(() {
            _selectedCategory = category;
            _selectedVehicleType = vehicleType;
            _showLowStock = lowStock;
          });
          _loadProducts(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = !widget.isShopkeeper;
    return Scaffold(
      appBar: widget.isShopkeeper || !widget.showAppBar
          ? null
          : AppBar(
              title: const Text('Supermarket Inventory'),
              actions: [
                IconButton(
                  tooltip: 'Scan Barcode to Add',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanAndAddProduct,
                ),
                IconButton(
                  tooltip: 'Add Product',
                  icon: const Icon(Icons.add),
                  onPressed: () => _openAddProduct(),
                ),
              ],
            ),
      floatingActionButton: isAdmin && !widget.showAppBar
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'scan_add_btn',
                  onPressed: _scanAndAddProduct,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan & Add'),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  heroTag: 'add_btn',
                  onPressed: () => _openAddProduct(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadProducts(reset: true);
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      if (v.isEmpty || v.length > 2) _loadProducts(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _selectedCategory != null ||
                      _selectedVehicleType != null ||
                      _showLowStock,
                  child: IconButton(
                    icon: const Icon(Icons.tune),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceVariant,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
          ),

          // Active filter chips
          if (_selectedCategory != null ||
              _selectedVehicleType != null ||
              _showLowStock)
            Container(
              height: 40,
              color: AppColors.surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_selectedCategory != null)
                    _FilterChip(
                      label: _selectedCategory!,
                      onRemove: () {
                        setState(() => _selectedCategory = null);
                        _loadProducts(reset: true);
                      },
                    ),
                  if (_selectedVehicleType != null)
                    _FilterChip(
                      label: _selectedVehicleType!,
                      onRemove: () {
                        setState(() => _selectedVehicleType = null);
                        _loadProducts(reset: true);
                      },
                    ),
                  if (_showLowStock)
                    _FilterChip(
                      label: 'Low Stock',
                      color: AppColors.warning,
                      onRemove: () {
                        setState(() => _showLowStock = false);
                        _loadProducts(reset: true);
                      },
                    ),
                ],
              ),
            ),

          // Product count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_products.length} products',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (_isLoading && _products.isEmpty)
                  const Text('Loading...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: _isLoading && _products.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(itemCount: 6),
                  )
                : _products.isEmpty
                    ? EmptyStateWidget(
                        message: 'No products found',
                        icon: Icons.inventory_2_outlined,
                        actionLabel: isAdmin ? 'Add Product' : null,
                        onAction: isAdmin ? _openAddProduct : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadProducts(reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _products.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _products.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final p = _products[i];
                            return ProductCard(
                              product: p,
                              onTap: () => context.push(
                                isAdmin
                                    ? '/admin/products/${p.id}'
                                    : '/shopkeeper/products/${p.id}',
                              ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: c),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? selectedCategory;
  final String? selectedVehicleType;
  final bool showLowStock;
  final Function(String?, String?, bool) onApply;

  const _FilterSheet({
    this.selectedCategory,
    this.selectedVehicleType,
    required this.showLowStock,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _category;
  String? _vehicleType;
  bool _lowStock = false;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _vehicleType = widget.selectedVehicleType;
    _lowStock = widget.showLowStock;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
          const Text('Filter Products',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora')),
          const SizedBox(height: 16),
          const Text('Category',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Sora')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppStrings.categories.map((cat) {
              final selected = _category == cat;
              return ChoiceChip(
                label: Text(cat, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) =>
                    setState(() => _category = v ? cat : null),
                selectedColor: AppColors.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Packaging / Unit Type',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Sora')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppStrings.vehicleTypes.map((vt) {
              final selected = _vehicleType == vt;
              return ChoiceChip(
                label: Text(vt, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) =>
                    setState(() => _vehicleType = v ? vt : null),
                selectedColor: AppColors.accent.withOpacity(0.15),
                labelStyle: TextStyle(
                    color: selected ? AppColors.accent : AppColors.textSecondary),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Low Stock Only',
                style: TextStyle(fontFamily: 'Sora', fontSize: 14)),
            value: _lowStock,
            activeThumbColor: AppColors.warning,
            onChanged: (v) => setState(() => _lowStock = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _category = null;
                      _vehicleType = null;
                      _lowStock = false;
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_category, _vehicleType, _lowStock);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add product (admin) ─────────────────────────────────────────────────────

class _AddProductSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final String? initialBarcode;

  const _AddProductSheet({required this.onSaved, this.initialBarcode});

  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '5');
  final _imageUrlController = TextEditingController();

  final _imagePicker = ImagePicker();
  String? _pickedImageBase64;

  List<ShopModel> _shops = [];
  String? _shopId;
  String? _category = AppStrings.categories.first;
  String? _vehicleType = AppStrings.vehicleTypes.first;
  bool _loadingShops = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
    _loadShops();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _lowStockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _pickedImageBase64 = base64Str;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(returnCodeOnly: true),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  Future<void> _loadShops() async {
    try {
      final data = await ref.read(apiServiceProvider).getShops();
      final shops = (data['shops'] as List<dynamic>? ?? [])
          .map((s) => ShopModel.fromJson(s))
          .where((s) => s.isActive)
          .toList();
      setState(() {
        _shops = shops;
        _shopId = shops.isNotEmpty ? shops.first.id : null;
        _loadingShops = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Could not load shops';
        _loadingShops = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a shop'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final imageVal = _pickedImageBase64 ??
          (_imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null);

      final isAdmin = ref.read(authProvider).user?.isAdmin ?? false;
      final sellingVal = double.parse(_sellingPriceController.text.trim());
      final purchaseVal = isAdmin && _purchasePriceController.text.trim().isNotEmpty
          ? (double.tryParse(_purchasePriceController.text.trim()) ?? sellingVal)
          : sellingVal;

      final res = await api.createProduct({
        'name': _nameController.text.trim(),
        'shop': _shopId,
        'category': _category,
        'vehicleType': _vehicleType,
        if (imageVal != null) 'image': imageVal,
        if (_barcodeController.text.trim().isNotEmpty)
          'barcode': _barcodeController.text.trim(),
        if (_brandController.text.trim().isNotEmpty)
          'brand': _brandController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
        'purchasePrice': purchaseVal,
        'sellingPrice': sellingVal,
        'quantity': int.parse(_quantityController.text.trim()),
        'lowStockThreshold': int.parse(_lowStockController.text.trim()),
      });

      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Product created'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to create product'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? 'Failed to create product'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: _loadingShops
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : _loadError != null
              ? SizedBox(
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!,
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loadingShops = true;
                              _loadError = null;
                            });
                            _loadShops();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
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
                        const Text(
                          'Add Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Sora',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildImagePickerField(),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product name *',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _barcodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Barcode / EAN (optional)',
                                  prefixIcon: Icon(Icons.qr_code_2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _scanBarcode,
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Scan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _shopId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Shop *'),
                          items: _shops
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    '${s.name} — ${s.location}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _shopId = v),
                          validator: (v) => v == null ? 'Select a shop' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Category *'),
                          items: AppStrings.categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _category = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _vehicleType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unit / Packaging *',
                          ),
                          items: AppStrings.vehicleTypes
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _vehicleType = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'Brand (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final isAdmin = ref.watch(authProvider).user?.isAdmin ?? false;
                            return Row(
                              children: [
                                if (isAdmin) ...[
                                  Expanded(
                                    child: TextFormField(
                                      controller: _purchasePriceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Purchase (ETB) *',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (isAdmin) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(v) == null) {
                                            return 'Invalid';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: TextFormField(
                                    controller: _sellingPriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Selling (ETB) *',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(v) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity *',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(v) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lowStockController,
                                decoration: const InputDecoration(
                                  labelText: 'Low stock at',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(v) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                child: _submitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Save Product'),
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

  Widget _buildImagePickerField() {
    final hasImage =
        _pickedImageBase64 != null || _imageUrlController.text.trim().isNotEmpty;
    final currentImage =
        _pickedImageBase64 ?? _imageUrlController.text.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Photo',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: 'Sora',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              buildProductImageWidget(
                currentImage.isNotEmpty ? currentImage : null,
                size: 64,
                borderRadius: 10,
                fallbackIcon: Icons.add_a_photo_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 14),
                          label: const Text('Camera', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 14),
                          label: const Text('Gallery', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    if (hasImage) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _pickedImageBase64 = null;
                            _imageUrlController.clear();
                          });
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 14, color: AppColors.error),
                            SizedBox(width: 4),
                            Text(
                              'Remove photo',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Or enter image URL (optional)',
              prefixIcon: Icon(Icons.link, size: 18),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
