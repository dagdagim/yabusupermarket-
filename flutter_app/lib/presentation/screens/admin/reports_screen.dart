import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ReportsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isLoading = false;
  String _selectedPeriod = 'daily';
  String? _selectedShopId;
  final _ekubController = TextEditingController();
  double _ekubContribution = 0;

  Map<String, dynamic>? _reportData;
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void dispose() {
    _ekubController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedEkub();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getReport(
        period: _selectedPeriod,
        shop: _selectedShopId,
      );
      if (!mounted) return;
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportReport(String type) async {
    try {
      final api = ref.read(apiServiceProvider);
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: AppConstants.accessTokenKey);

      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final baseUrl = api.getReportExportUrl(type, period: _selectedPeriod);
      var exportUrl = '$baseUrl&token=$token';
      if (_selectedShopId != null) {
        exportUrl += '&shop=$_selectedShopId';
      }

      final uri = Uri.parse(exportUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Downloading ${type.toUpperCase()} report...'),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Analytics & Reports'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReport,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Filter Section
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
                        'Analytics & Reports',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Sora'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadReport,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Shop & Period Selection Row
                Row(
                  children: [
                    // Period Selector ChoiceChips
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['daily', 'weekly', 'monthly'].map((p) {
                            final isSel = _selectedPeriod == p;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(p.toUpperCase(),
                                    style: const TextStyle(fontSize: 10)),
                                selected: isSel,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedPeriod = p);
                                    _loadReport();
                                  }
                                },
                                selectedColor: AppColors.primary.withOpacity(0.12),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Export Actions
                    ElevatedButton.icon(
                      onPressed: () => _exportReport('pdf'),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _exportReport('excel'),
                      icon: const Icon(Icons.table_chart, size: 14),
                      label: const Text('Excel', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Shops Selector Row
                shopsAsync.when(
                  data: (shops) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Shops',
                                style: TextStyle(fontSize: 11)),
                            selected: _selectedShopId == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedShopId = null);
                                _loadReport();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ...shops.map((shop) {
                            final isSelected = _selectedShopId == shop.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(shop.name,
                                    style: const TextStyle(fontSize: 11)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedShopId = shop.id);
                                    _loadReport();
                                  }
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 10),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Main Scrollable Report Content
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(itemCount: 5),
                  )
                : _reportData == null
                    ? EmptyStateWidget(
                        message: 'No analytics data loaded',
                        icon: Icons.bar_chart_outlined,
                        actionLabel: 'Load Now',
                        onAction: _loadReport,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReport,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // KPI grid
                              _buildKPIGrid(),
                              const SizedBox(height: 20),

                              _buildEkubProfitSection(),
                              const SizedBox(height: 20),

                              // Trend chart
                              _buildTrendChartSection(),
                              const SizedBox(height: 20),

                              // Top selling products
                              _buildTopProductsSection(),
                              const SizedBox(height: 20),

                              // Shop breakdown
                              if (_selectedShopId == null) ...[
                                _buildShopBreakdownSection(),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }


  Future<void> _loadSavedEkub() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final saved = await storage.read(key: 'saved_ekub_contribution');
      if (saved != null && mounted) {
        final val = double.tryParse(saved) ?? 0;
        setState(() {
          _ekubContribution = val;
          _ekubController.text = val > 0 ? val.toStringAsFixed(0) : '';
        });
      }
    } catch (_) {}
  }

  Future<void> _submitEkub() async {
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.write(
        key: 'saved_ekub_contribution',
        value: _ekubContribution.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ekub contribution of ${_fmt.format(_ekubContribution)} ETB submitted and saved!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Ekub: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEkubProfitSection() {
    final sum = _reportData!['summary'] as Map<String, dynamic>? ?? {};
    final profit = (sum['totalProfit'] ?? 0).toDouble();
    final remainingProfit = profit - _ekubContribution;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekub Profit Calculator',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ekubController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Ekub Contribution (ETB)',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              onChanged: (value) {
                setState(() {
                  _ekubContribution = double.tryParse(value.trim()) ?? 0;
                });
              },
            ),
            const SizedBox(height: 14),
            _ProfitBreakdownRow(
              label: 'Total Profit Margin',
              value: '${_fmt.format(profit)} ETB',
              color: AppColors.info,
            ),
            _ProfitBreakdownRow(
              label: 'Ekub Deduction',
              value: '- ${_fmt.format(_ekubContribution)} ETB',
              color: AppColors.warning,
            ),
            const Divider(height: 18),
            _ProfitBreakdownRow(
              label: 'Remaining Profit',
              value: '${_fmt.format(remainingProfit)} ETB',
              color: remainingProfit >= 0 ? AppColors.success : AppColors.error,
              bold: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitEkub,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Submit Ekub Contribution'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIGrid() {
    final sum = _reportData!['summary'] as Map<String, dynamic>? ?? {};
    final revenue = (sum['totalRevenue'] ?? 0).toDouble();
    final profit = (sum['totalProfit'] ?? 0).toDouble();
    final transactions = sum['totalTransactions'] ?? 0;
    final itemsSold = sum['totalItemsSold'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReportSummaryCard(
                label: 'Revenue',
                value: '${_fmt.format(revenue)} ETB',
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportSummaryCard(
                label: 'Profit Margin',
                value: '${_fmt.format(profit)} ETB',
                icon: Icons.savings_outlined,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReportSummaryCard(
                label: 'Transactions',
                value: '$transactions',
                icon: Icons.receipt_long,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportSummaryCard(
                label: 'Items Sold',
                value: '$itemsSold',
                icon: Icons.inventory_2_outlined,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendChartSection() {
    final trendList = _reportData!['dailyTrend'] as List<dynamic>? ?? [];
    if (trendList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
              child: Text('No trend data available',
                  style: TextStyle(color: AppColors.textSecondary))),
        ),
      );
    }

    final List<FlSpot> spotsRevenue = [];
    final List<FlSpot> spotsProfit = [];

    double maxVal = 0.0;
    for (int i = 0; i < trendList.length; i++) {
      final t = trendList[i];
      final rev = (t['revenue'] ?? 0.0).toDouble();
      final prof = (t['profit'] ?? 0.0).toDouble();
      spotsRevenue.add(FlSpot(i.toDouble(), rev));
      spotsProfit.add(FlSpot(i.toDouble(), prof));
      if (rev > maxVal) maxVal = rev;
    }

    final double maxY = maxVal > 0 ? (maxVal * 1.15) : 1000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales & Profit Trend',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _ChartLegendItem(color: AppColors.success, label: 'Revenue'),
                const SizedBox(width: 12),
                _ChartLegendItem(color: AppColors.info, label: 'Profit'),
              ],
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.divider,
                      strokeWidth: 0.8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final int idx = value.toInt();
                          if (idx >= 0 && idx < trendList.length) {
                            final dateObj = trendList[idx]['_id'] ?? {};
                            if (dateObj['day'] != null && dateObj['month'] != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${dateObj['month']}/${dateObj['day']}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}k'
                                : value.toStringAsFixed(0),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (trendList.length - 1).toDouble().clamp(1.0, double.infinity),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsRevenue,
                      isCurved: trendList.length > 2,
                      color: AppColors.success,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withOpacity(0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: spotsProfit,
                      isCurved: trendList.length > 2,
                      color: AppColors.info,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.info.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection() {
    final topProds = _reportData!['topProducts'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Selling Products',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora'),
            ),
            const SizedBox(height: 12),
            topProds.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No top selling products data',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topProds.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, i) {
                      final p = topProds[i];
                      final name = p['productName'] ?? 'Unknown';
                      final totalSold = p['totalSold'] ?? 0;
                      final revenue = (p['totalRevenue'] ?? 0.0).toDouble();

                      return Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$totalSold unit(s) sold',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_fmt.format(revenue)} ETB',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopBreakdownSection() {
    final breakdown = _reportData!['shopBreakdown'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shop Performance Breakdown',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora'),
            ),
            const SizedBox(height: 12),
            breakdown.isEmpty
                ? const Center(
                    child: Text('No shop breakdown data available',
                        style: TextStyle(color: AppColors.textSecondary)))
                : Column(
                    children: breakdown.map((item) {
                      final shopName = item['shopName'] ?? 'Unknown Shop';
                      final revenue = (item['totalRevenue'] ?? 0.0).toDouble();
                      final profit = (item['totalProfit'] ?? 0.0).toDouble();
                      final txns = item['totalTransactions'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.divider.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shopName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$txns transactions',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_fmt.format(revenue)} ETB',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                      fontSize: 14),
                                ),
                                Text(
                                  'Profit: ${_fmt.format(profit)} ETB',
                                  style: const TextStyle(
                                      color: AppColors.info, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ProfitBreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _ProfitBreakdownRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontFamily: 'Sora',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Sora',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
