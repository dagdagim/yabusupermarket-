import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class ReconciliationScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ReconciliationScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  List<ReconciliationModel> _reconciliations = [];
  bool _isLoading = false;
  final DateTime _selectedDate = DateTime.now();
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadReconciliations();
  }

  Future<void> _loadReconciliations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getReconciliations();
      if (!mounted) return;
      setState(() {
        _reconciliations = (data['reconciliations'] as List<dynamic>? ?? [])
            .map((r) => ReconciliationModel.fromJson(r))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _generateForDate() async {
    final shops = await ref.read(apiServiceProvider).getShops();
    final shopList = (shops['shops'] as List<dynamic>? ?? [])
        .map((s) => ShopModel.fromJson(s))
        .toList();

    if (!mounted || shopList.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => _GenerateDialog(
        shops: shopList,
        date: _selectedDate,
        onGenerate: (shopId, date) async {
          Navigator.pop(ctx);
          try {
            final api = ref.read(apiServiceProvider);
            await api.generateReconciliation(shopId, date.toIso8601String());
            await _loadReconciliations();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Reconciliation generated'),
                    backgroundColor: AppColors.success),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Cash Reconciliation'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _generateForDate,
                  tooltip: 'Generate',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReconciliations,
                ),
              ],
            )
          : null,
      floatingActionButton: !widget.showAppBar
          ? FloatingActionButton.extended(
              onPressed: _generateForDate,
              icon: const Icon(Icons.add),
              label: const Text('Generate Reconciliation'),
            )
          : null,
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16), child: ShimmerList())
          : _reconciliations.isEmpty
              ? EmptyStateWidget(
                  message: 'No reconciliation records yet',
                  icon: Icons.account_balance_wallet_outlined,
                  actionLabel: 'Generate Now',
                  onAction: _generateForDate,
                )
              : RefreshIndicator(
                  onRefresh: _loadReconciliations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reconciliations.length,
                    itemBuilder: (_, i) => _ReconciliationCard(
                      reconciliation: _reconciliations[i],
                      fmt: _fmt,
                      onTap: () => _showUpdateDialog(_reconciliations[i]),
                    ),
                  ),
                ),
    );
  }

  void _showUpdateDialog(ReconciliationModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateReconciliationSheet(
        reconciliation: r,
        fmt: _fmt,
        onUpdated: _loadReconciliations,
      ),
    );
  }
}

class _ReconciliationCard extends StatelessWidget {
  final ReconciliationModel reconciliation;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _ReconciliationCard({
    required this.reconciliation,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = reconciliation;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.shopName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Sora')),
                      Text(
                        DateFormat('EEE, d MMM yyyy').format(r.date),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  StatusBadge(status: r.status),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatItem(
                      label: 'Expected',
                      value: '${fmt.format(r.expectedCash)} ETB',
                      color: AppColors.primary),
                  _StatItem(
                      label: 'Received',
                      value: r.cashReceived > 0
                          ? '${fmt.format(r.cashReceived)} ETB'
                          : '—',
                      color: AppColors.success),
                  _StatItem(
                      label: 'Difference',
                      value: r.cashReceived > 0
                          ? '${fmt.format(r.difference)} ETB'
                          : '—',
                      color: r.difference < 0
                          ? AppColors.error
                          : r.difference > 0
                              ? AppColors.warning
                              : AppColors.success),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${r.totalTransactions} transactions',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  if (r.status == 'pending')
                    const Text('Tap to update →',
                        style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color, fontFamily: 'Sora')),
      ],
    );
  }
}

class _UpdateReconciliationSheet extends ConsumerStatefulWidget {
  final ReconciliationModel reconciliation;
  final NumberFormat fmt;
  final VoidCallback onUpdated;

  const _UpdateReconciliationSheet({
    required this.reconciliation,
    required this.fmt,
    required this.onUpdated,
  });

  @override
  ConsumerState<_UpdateReconciliationSheet> createState() =>
      _UpdateReconciliationSheetState();
}

class _UpdateReconciliationSheetState
    extends ConsumerState<_UpdateReconciliationSheet> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'pending';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reconciliation;
    _status = r.status;
    if (r.cashReceived > 0) {
      _cashController.text = r.cashReceived.toStringAsFixed(0);
    }
    _notesController.text = r.notes ?? '';
  }

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateReconciliation(widget.reconciliation.id, {
        'cashReceived': double.tryParse(_cashController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'status': _status,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reconciliation updated'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reconciliation;
    final fmt = widget.fmt;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(r.shopName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Sora')),
            Text(DateFormat('EEEE, d MMM yyyy').format(r.date),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                InfoRow(
                    label: 'Total Sales',
                    value: '${fmt.format(r.totalSales)} ETB',
                    valueColor: AppColors.primary),
                InfoRow(
                    label: 'Transactions',
                    value: '${r.totalTransactions}'),
                InfoRow(
                    label: 'Expected Cash',
                    value: '${fmt.format(r.expectedCash)} ETB',
                    valueColor: AppColors.success),
              ]),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cash Received (ETB)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            const Text('Status',
                style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Sora')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['pending', 'verified', 'completed'].map((s) {
                final sel = _status == s;
                return ChoiceChip(
                  label: Text(s.toUpperCase(),
                      style: const TextStyle(fontSize: 11)),
                  selected: sel,
                  onSelected: (v) => setState(() => _status = s),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Reconciliation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateDialog extends StatefulWidget {
  final List<ShopModel> shops;
  final DateTime date;
  final Function(String shopId, DateTime date) onGenerate;

  const _GenerateDialog({
    required this.shops,
    required this.date,
    required this.onGenerate,
  });

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  String? _selectedShopId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    if (widget.shops.isNotEmpty) {
      _selectedShopId = widget.shops.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Generate Reconciliation',
          style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedShopId,
            decoration: const InputDecoration(labelText: 'Shop'),
            items: widget.shops
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedShopId = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date', style: TextStyle(fontFamily: 'Sora')),
            subtitle: Text(DateFormat('d MMM yyyy').format(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedShopId == null
              ? null
              : () => widget.onGenerate(_selectedShopId!, _date),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
