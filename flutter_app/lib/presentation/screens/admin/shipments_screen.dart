import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class ShipmentsScreen extends ConsumerStatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  ConsumerState<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends ConsumerState<ShipmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<ShipmentModel> _pending = [];
  final List<ShipmentModel> _arrived = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final _fmt = DateFormat('d MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadShipments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShipments() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final pendingData = await api.getShipments(status: 'pending');
      final arrivedData = await api.getShipments(status: 'arrived');
      setState(() {
        _pending
          ..clear()
          ..addAll((pendingData['data'] as List<dynamic>? ?? [])
              .map((s) => ShipmentModel.fromJson(s)));
        _arrived
          ..clear()
          ..addAll((arrivedData['data'] as List<dynamic>? ?? [])
              .map((s) => ShipmentModel.fromJson(s)));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shipments: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _verifyShipment(ShipmentModel shipment) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Verify Arrival',
      message:
          'Add ${shipment.quantity} unit(s) of ${shipment.productName} to ${shipment.shopName} inventory?',
      confirmLabel: 'Verify',
      confirmColor: AppColors.success,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final data = await ref.read(apiServiceProvider).verifyShipment(shipment.id);
      if (data['success'] == true) {
        ref.invalidate(pendingShipmentsProvider);
        ref.invalidate(lowStockProvider);
        await _loadShipments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shipment arrival verified'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _CreateShipmentSheet(api: ref.read(apiServiceProvider)),
    );

    if (created == true) {
      ref.invalidate(pendingShipmentsProvider);
      await _loadShipments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shipped Products'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadShipments,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Pending (${_pending.length})'),
              Tab(text: 'Arrived (${_arrived.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(itemCount: 6),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _ShipmentList(
                    shipments: _pending,
                    emptyMessage: 'No pending shipments',
                    dateFormatter: _fmt,
                    onVerify: _verifyShipment,
                  ),
                  _ShipmentList(
                    shipments: _arrived,
                    emptyMessage: 'No verified shipments yet',
                    dateFormatter: _fmt,
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateSheet,
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Ship Product'),
        ),
      ),
    );
  }
}

class _ShipmentList extends StatelessWidget {
  final List<ShipmentModel> shipments;
  final String emptyMessage;
  final DateFormat dateFormatter;
  final ValueChanged<ShipmentModel>? onVerify;

  const _ShipmentList({
    required this.shipments,
    required this.emptyMessage,
    required this.dateFormatter,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    if (shipments.isEmpty) {
      return EmptyStateWidget(
        message: emptyMessage,
        icon: Icons.local_shipping_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: shipments.length,
        itemBuilder: (_, i) {
          final shipment = shipments[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: (shipment.isPending
                                  ? AppColors.warning
                                  : AppColors.success)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          shipment.isPending
                              ? Icons.pending_actions_outlined
                              : Icons.verified_outlined,
                          color: shipment.isPending
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shipment.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora',
                              ),
                            ),
                            Text(
                              '${shipment.quantity} unit(s) to ${shipment.shopName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: shipment.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    label: 'Shipped',
                    value: dateFormatter.format(shipment.shippedAt.toLocal()),
                  ),
                  if (shipment.arrivedAt != null)
                    InfoRow(
                      label: 'Arrived',
                      value: dateFormatter.format(shipment.arrivedAt!.toLocal()),
                    ),
                  if (shipment.notes != null && shipment.notes!.isNotEmpty) ...[
                    const Divider(height: 18),
                    Text(
                      shipment.notes!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (shipment.isPending && onVerify != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onVerify!(shipment),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Verify Arrival'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateShipmentSheet extends ConsumerStatefulWidget {
  final ApiService api;

  const _CreateShipmentSheet({required this.api});

  @override
  ConsumerState<_CreateShipmentSheet> createState() =>
      _CreateShipmentSheetState();
}

class _CreateShipmentSheetState extends ConsumerState<_CreateShipmentSheet> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  List<ProductModel> _products = [];
  List<ShopModel> _shops = [];
  ProductModel? _selectedProduct;
  ShopModel? _selectedShop;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _loadFormData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final productData = await widget.api.getProducts(limit: 100);
      final shopData = await widget.api.getShops();
      setState(() {
        _products = (productData['data'] as List<dynamic>? ?? [])
            .map((p) => ProductModel.fromJson(p))
            .toList();
        _shops = (shopData['shops'] as List<dynamic>? ?? [])
            .map((s) => ShopModel.fromJson(s))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shipment form: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (_selectedProduct == null || _selectedShop == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose product, shop, and a valid quantity'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = await widget.api.createShipment({
        'productId': _selectedProduct!.id,
        'shopId': _selectedShop!.id,
        'quantity': quantity,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shipment recorded'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record shipment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Record Shipment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductModel>(
                        value: _selectedProduct,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: _products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  '${p.name} (${p.quantity} in stock)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedProduct = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ShopModel>(
                        value: _selectedShop,
                        decoration: const InputDecoration(
                          labelText: 'Destination Shop',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        items: _shops
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedShop = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: Icon(Icons.note_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Record Shipment'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
