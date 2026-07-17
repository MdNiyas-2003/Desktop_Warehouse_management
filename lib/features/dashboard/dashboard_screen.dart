import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/premium_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BackendApi _api = BackendApi();
  String? _selectedOrderId;
  late Future<List<_OrderViewModel>> _ordersFuture;
  Timer? _ordersRefreshTimer;
  // TODO: Re-enable inventory allocation panel in next update.
  bool _showInventoryAllocatePanel = false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
    _ordersRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() {
        _ordersFuture = _loadOrders();
      });
    });
  }

  @override
  void dispose() {
    _ordersRefreshTimer?.cancel();
    super.dispose();
  }

  Future<List<_OrderViewModel>> _loadOrders() async {
    try {
      final response = await _api.getOrders();
      if (response.isEmpty) return _sampleOrders;
      return response.map(_OrderViewModel.fromMap).toList();
    } catch (_) {
      return _sampleOrders;
    }
  }

  Future<void> _showOrderDetailsDialog(_OrderViewModel order) async {
    setState(() => _selectedOrderId = order.id);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _OrderDetailsDialog(
          order: order,
          onApprove: () async {
            if (order.status == 'Approved') {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Order is already Approved.')),
              );
              return;
            }
            if (order.id == null) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This is demo data. Use Firestore order to update status.',
                  ),
                ),
              );
              return;
            }
            await _updateOrderStatus(order.id, 'Approved');
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          onReject: () async {
            if (order.status == 'Rejected') {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Order is already Rejected.')),
              );
              return;
            }
            if (order.id == null) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This is demo data. Use Firestore order to update status.',
                  ),
                ),
              );
              return;
            }
            await _updateOrderStatus(order.id, 'Rejected');
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_OrderViewModel>>(
      future: _ordersFuture,
      builder: (context, orderSnapshot) {
        final orders = _buildOrders(orderSnapshot.data);
        final selected = _resolveSelectedOrder(orders);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('inventory')
              .snapshots(),
          builder: (context, inventorySnapshot) {
            final inventory = _computeInventory(inventorySnapshot.data);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, userSnapshot) {
                final kpis = _buildKpis(orders);
                _computeUsers(userSnapshot.data);
                _buildReportData(orders);
                _buildRegionSlices(orders);
                _buildTopProducts(orders);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroHeader(
                        loading:
                            orderSnapshot.connectionState ==
                            ConnectionState.waiting,
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = constraints.maxWidth >= 980
                              ? 5
                              : constraints.maxWidth >= 760
                              ? 2
                              : 1;
                          return GridView.builder(
                            itemCount: kpis.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: count == 5 ? 2.55 : 2.4,
                                ),
                            itemBuilder: (context, index) =>
                                _KpiTile(data: kpis[index]),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1360;
                          final gap = 14.0;
                          final available =
                              constraints.maxWidth - (wide ? gap * 2 : 0);
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              SizedBox(
                                width: wide
                                    ? available * 0.66
                                    : constraints.maxWidth,
                                child: _LiveIncomingOrdersCard(
                                  orders: orders,
                                  selectedOrderId: _selectedOrderId,
                                  onView: _showOrderDetailsDialog,
                                ),
                              ),
                              if (_showInventoryAllocatePanel)
                                SizedBox(
                                  width: wide
                                      ? available * 0.34
                                      : constraints.maxWidth,
                                  child: _InventoryAndAllocateCard(
                                    inventory: inventory,
                                    orders: orders
                                        .where((o) => o.status == 'Approved')
                                        .take(3)
                                        .toList(),
                                    onAllocate: (order) => _updateOrderStatus(
                                      order.id!,
                                      'Ready to Dispatch',
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 14.0;
                          const panelHeight = 332.0;

                          final dispatchCard = _DispatchCard(
                            order: selected,
                            onDispatch:
                                (
                                  orderCode,
                                  transportName,
                                  dispatchAssignee,
                                  dispatchDateTime,
                                  expectedDeliveryDateTime,
                                ) => _dispatchOrderFromForm(
                                  orders: orders,
                                  orderCode: orderCode,
                                  transportName: transportName,
                                  dispatchAssignee: dispatchAssignee,
                                  dispatchDateTime: dispatchDateTime,
                                  expectedDeliveryDateTime:
                                      expectedDeliveryDateTime,
                                ),
                          );

                          final deliveryCard = _DeliveryStatusCard(
                            orders: orders,
                          );

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: panelHeight,
                                      child: dispatchCard,
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  Expanded(
                                    child: SizedBox(
                                      height: panelHeight,
                                      child: deliveryCard,
                                    ),
                                  ),
                                ],
                              ),
                              // TODO: Enable user management section later.
                              // const SizedBox(height: 14),
                              // SizedBox(
                              //   width: constraints.maxWidth,
                              //   child: _UserManagementCard(stats: userStats),
                              // ),
                            ],
                          );
                        },
                      ),
                      // TODO: Enable analytics section later.
                      // Includes: Daily Orders, Monthly Sales,
                      // Sales by Region, and Top Products.
                      // const SizedBox(height: 14),
                      // LayoutBuilder(
                      //   builder: (context, constraints) {
                      //     final wide = constraints.maxWidth >= 1360;
                      //     final gap = 14.0;
                      //     final available =
                      //         constraints.maxWidth - (wide ? gap : 0);
                      //     return Wrap(
                      //       spacing: gap,
                      //       runSpacing: gap,
                      //       children: [
                      //         SizedBox(
                      //           width: wide
                      //               ? available * 0.62
                      //               : constraints.maxWidth,
                      //           child: _ReportsChartsCard(data: reportData),
                      //         ),
                      //         SizedBox(
                      //           width: wide
                      //               ? available * 0.38
                      //               : constraints.maxWidth,
                      //           child: _TopProductsAndNotesCard(
                      //             regionSlices: regionSlices,
                      //             topProducts: topProducts,
                      //           ),
                      //         ),
                      //       ],
                      //     );
                      //   },
                      // ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<_OrderViewModel> _buildOrders(List<_OrderViewModel>? orders) {
    if (orders == null || orders.isEmpty) {
      return _sampleOrders;
    }

    return orders;
  }

  _OrderViewModel _resolveSelectedOrder(List<_OrderViewModel> orders) {
    if (orders.isEmpty) {
      return _sampleOrders.first;
    }

    if (_selectedOrderId == null) {
      return orders.first;
    }

    return orders.firstWhere(
      (o) => o.id == _selectedOrderId,
      orElse: () => orders.first,
    );
  }

  _InventorySummary _computeInventory(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null || snapshot.docs.isEmpty) {
      return const _InventorySummary(
        availableStock: 18450,
        reservedStock: 6320,
        lowStockSkus: 24,
      );
    }

    double available = 0;
    double reserved = 0;
    int low = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final stock = _asNum(data['availableStock'] ?? data['stock'] ?? 0);
      final reservedStock = _asNum(data['reservedStock'] ?? 0);
      final reorderLevel = _asNum(data['reorderLevel'] ?? 10);
      available += stock;
      reserved += reservedStock;
      if (stock <= reorderLevel) {
        low += 1;
      }
    }

    return _InventorySummary(
      availableStock: available.round(),
      reservedStock: reserved.round(),
      lowStockSkus: low,
    );
  }

  _UserStats _computeUsers(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null || snapshot.docs.isEmpty) {
      return const _UserStats(salesmen: 42, warehouseStaff: 16, admins: 4);
    }

    int salesmen = 0;
    int warehouse = 0;
    int admins = 0;

    for (final doc in snapshot.docs) {
      final role = (doc.data()['role'] ?? '').toString().toLowerCase();
      if (role.contains('sales')) {
        salesmen += 1;
      } else if (role.contains('warehouse')) {
        warehouse += 1;
      } else if (role.contains('admin')) {
        admins += 1;
      }
    }

    return _UserStats(
      salesmen: salesmen,
      warehouseStaff: warehouse,
      admins: admins,
    );
  }

  List<_KpiData> _buildKpis(List<_OrderViewModel> orders) {
    final today = DateTime.now();
    final todays = orders.where((o) => _isSameDay(o.createdAt, today)).length;
    final pending = orders.where((o) => o.status == 'Pending').length;
    final approved = orders.where((o) => o.status == 'Approved').length;
    final ready = orders.where((o) => o.status == 'Ready to Dispatch').length;
    final delivered = orders.where((o) => o.status == 'Delivered').length;

    return [
      _KpiData(
        'Today\'s Orders',
        '$todays',
        Icons.today_rounded,
        const Color(0xFF2E5BFF),
        '+$todays',
      ),
      _KpiData(
        'Pending Orders',
        '$pending',
        Icons.hourglass_bottom_rounded,
        const Color(0xFFFFB547),
        '+$pending',
      ),
      _KpiData(
        'Approved',
        '$approved',
        Icons.check_circle_outline_rounded,
        const Color(0xFF22C55E),
        '+$approved',
      ),
      _KpiData(
        'Ready to Dispatch',
        '$ready',
        Icons.local_shipping_rounded,
        const Color(0xFF0EA5E9),
        '+$ready',
      ),
      _KpiData(
        'Delivered',
        '$delivered',
        Icons.check_circle_rounded,
        const Color(0xFF22C55E),
        '+$delivered',
      ),
    ];
  }

  _ReportSeries _buildReportData(List<_OrderViewModel> orders) {
    final last12Days = List.generate(
      12,
      (i) => DateTime.now().subtract(Duration(days: 11 - i)),
    );
    final dailyCounts = <double>[];

    for (final day in last12Days) {
      dailyCounts.add(
        orders.where((o) => _isSameDay(o.createdAt, day)).length.toDouble(),
      );
    }

    final monthSales = List<double>.filled(12, 0);
    for (final order in orders) {
      final m = order.createdAt.month - 1;
      monthSales[m] += order.amount;
    }

    final monthSalesK = monthSales
        .map((value) => (value / 1000).clamp(1, 99999).toDouble())
        .toList();

    return _ReportSeries(dailyOrders: dailyCounts, monthlySales: monthSalesK);
  }

  List<ChartSlice> _buildRegionSlices(List<_OrderViewModel> orders) {
    final totals = <String, double>{
      'North': 0,
      'South': 0,
      'East': 0,
      'West': 0,
    };
    for (final order in orders) {
      if (totals.containsKey(order.region)) {
        totals[order.region] = totals[order.region]! + order.amount;
      }
    }

    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return const [
        ChartSlice('North', 32, Color(0xFF2E5BFF)),
        ChartSlice('South', 24, Color(0xFF22C55E)),
        ChartSlice('East', 20, Color(0xFFFFB547)),
        ChartSlice('West', 24, Color(0xFF8B5CF6)),
      ];
    }

    return [
      ChartSlice(
        'North',
        (totals['North']! / total) * 100,
        const Color(0xFF2E5BFF),
      ),
      ChartSlice(
        'South',
        (totals['South']! / total) * 100,
        const Color(0xFF22C55E),
      ),
      ChartSlice(
        'East',
        (totals['East']! / total) * 100,
        const Color(0xFFFFB547),
      ),
      ChartSlice(
        'West',
        (totals['West']! / total) * 100,
        const Color(0xFF8B5CF6),
      ),
    ];
  }

  List<_TopProductData> _buildTopProducts(List<_OrderViewModel> orders) {
    final aggregate = <String, _TopProductData>{};

    for (final order in orders) {
      final products = order.rawProducts;
      if (products.isEmpty) {
        aggregate.putIfAbsent(
          'General Items',
          () => const _TopProductData('General Items', 0, 0),
        );
        final current = aggregate['General Items']!;
        aggregate['General Items'] = _TopProductData(
          current.name,
          current.units + order.quantity,
          current.value + order.amount,
        );
        continue;
      }

      for (final p in products) {
        final name = (p['name'] ?? 'Item').toString();
        final qty = _asNum(p['quantity'] ?? 0);
        final lineTotal = _asNum(p['total'] ?? p['lineTotal'] ?? 0);
        aggregate.putIfAbsent(name, () => _TopProductData(name, 0, 0));
        final current = aggregate[name]!;
        aggregate[name] = _TopProductData(
          name,
          current.units + qty,
          current.value +
              (lineTotal > 0 ? lineTotal : order.amount / products.length),
        );
      }
    }

    final list = aggregate.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (list.isEmpty) {
      return const [
        _TopProductData('Premium Soap 100g', 2860, 429000),
        _TopProductData('Shampoo 200ml', 2120, 366000),
        _TopProductData('Detergent 1kg', 1720, 318000),
        _TopProductData('Surface Cleaner', 1140, 184000),
      ];
    }

    return list.take(4).toList();
  }

  Future<void> _updateOrderStatus(
    String? orderId,
    String status, {
    String? transportName,
    String? dispatchAssignee,
    DateTime? dispatchDateTime,
    DateTime? expectedDeliveryTime,
    DateTime? deliveredTime,
  }) async {
    if (orderId == null) {
      return;
    }
    try {
      await _api.updateOrderStatus(
        orderId,
        status,
        transportName: transportName,
        dispatchAssignee: dispatchAssignee,
        dispatchTime: dispatchDateTime,
        expectedDeliveryTime: expectedDeliveryTime,
        deliveredTime: deliveredTime,
      );
      if (!mounted) return;
      setState(() {
        _ordersFuture = _loadOrders();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update order status. ($e)')),
      );
    }
  }

  Future<void> _dispatchOrderFromForm({
    required List<_OrderViewModel> orders,
    required String orderCode,
    required String transportName,
    required String dispatchAssignee,
    required DateTime dispatchDateTime,
    required DateTime expectedDeliveryDateTime,
  }) async {
    final normalized = orderCode.trim().toLowerCase();
    _OrderViewModel? matched;

    for (final order in orders) {
      final orderIdMatch = order.orderId.trim().toLowerCase() == normalized;
      final docIdMatch = (order.id ?? '').trim().toLowerCase() == normalized;
      if (orderIdMatch || docIdMatch) {
        matched = order;
        break;
      }
    }

    if (matched == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order ID not found in live orders.')),
      );
      return;
    }

    await _updateOrderStatus(
      matched.id ?? matched.orderId,
      'In Transit',
      transportName: transportName,
      dispatchAssignee: dispatchAssignee,
      dispatchDateTime: dispatchDateTime,
      expectedDeliveryTime: expectedDeliveryDateTime,
    );

    if (!mounted) {
      return;
    }
    setState(() => _selectedOrderId = matched!.id ?? matched.orderId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dispatched ${matched.orderId} successfully.')),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDFEFF), Color(0xFFF5F9FF)],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xFF2E5BFF), Color(0xFF5A8BFF)],
              ),
            ),
            child: const Icon(Icons.warehouse_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warehouse/Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Connecting to live orders and stock data...'
                      : 'Live order pipeline, dispatch control, inventory allocation and user management.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: Text(loading ? 'Syncing' : 'Live Data'),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color, this.delta);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String delta;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            data.delta,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              color: data.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveIncomingOrdersCard extends StatefulWidget {
  const _LiveIncomingOrdersCard({
    required this.orders,
    required this.selectedOrderId,
    required this.onView,
  });

  final List<_OrderViewModel> orders;
  final String? selectedOrderId;
  final ValueChanged<_OrderViewModel> onView;

  @override
  State<_LiveIncomingOrdersCard> createState() =>
      _LiveIncomingOrdersCardState();
}

class _LiveIncomingOrdersCardState extends State<_LiveIncomingOrdersCard> {
  @override
  Widget build(BuildContext context) {
    final livePendingOrders =
        widget.orders.where((o) => o.status == 'Pending').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live Incoming Orders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFE8F7EE),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF1EAE61), size: 8),
                    SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1EAE61),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'New orders appear immediately after a salesman submits them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              const _IncomingOrdersHeader(),
              const Divider(height: 1),
              ...livePendingOrders
                  .take(5)
                  .map(
                    (order) => _IncomingOrderRow(
                      order: order,
                      selected:
                          widget.selectedOrderId != null &&
                          order.id == widget.selectedOrderId,
                      onView: () => widget.onView(order),
                    ),
                  ),
              if (livePendingOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No pending live orders.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomingOrdersHeader extends StatelessWidget {
  const _IncomingOrdersHeader();

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {double flex = 1}) {
      return Expanded(
        flex: (flex * 100).toInt(),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          cell('Order ID', flex: 0.88),
          cell('Salesman', flex: 0.82),
          cell('Shop', flex: 1.05),
          cell('Region', flex: 0.64),
          cell('Time', flex: 0.56),
          cell('Amount', flex: 0.75),
          cell('Status', flex: 0.7),
          cell('Actions', flex: 0.68),
        ],
      ),
    );
  }
}

class _IncomingOrderRow extends StatelessWidget {
  const _IncomingOrderRow({
    required this.order,
    required this.selected,
    required this.onView,
  });

  final _OrderViewModel order;
  final bool selected;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    Widget cell(Widget child, {double flex = 1}) {
      return Expanded(flex: (flex * 100).toInt(), child: child);
    }

    Widget action(String text, Color color, VoidCallback? onPressed) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          minimumSize: const Size(72, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: selected ? const Color(0xFFF2F7FF) : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                cell(Text(order.orderId), flex: 0.88),
                cell(Text(order.salesman), flex: 0.82),
                cell(Text(order.shop), flex: 1.05),
                cell(Text(order.region), flex: 0.64),
                cell(Text(order.timeText), flex: 0.56),
                cell(
                  Text(
                    _rupee(order.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  flex: 0.75,
                ),
                cell(
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 102),
                      child: StatusBadge(
                        label: order.status,
                        color: statusColor,
                        compact: true,
                      ),
                    ),
                  ),
                  flex: 0.7,
                ),
                cell(
                  Row(
                    children: [action('View', const Color(0xFF2E5BFF), onView)],
                  ),
                  flex: 0.68,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _OrderDetailsDialog extends StatelessWidget {
  const _OrderDetailsDialog({
    required this.order,
    required this.onApprove,
    required this.onReject,
  });

  final _OrderViewModel order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final products = order.productsForDialog;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDFEFF), Color(0xFFF5F9FF)],
          ),
          border: Border.all(color: const Color(0xFFDCE8FF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1C3A6B),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 980, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFFE8F7EE),
                            ),
                            child: const Text(
                              'Live Order',
                              style: TextStyle(
                                color: Color(0xFF179B56),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OrderMetaGrid(order: order),
                        const SizedBox(height: 14),
                        Text(
                          'Items',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        _OrderItemsTable(items: products),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderMetaGrid extends StatelessWidget {
  const _OrderMetaGrid({required this.order});

  final _OrderViewModel order;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final columnWidth = compact
            ? constraints.maxWidth
            : constraints.maxWidth / 2 - 8;

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(label: 'Order ID', value: order.orderId),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Shop Information',
                value: order.shop,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Salesman Information',
                value: order.salesman,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Ordered Products',
                value: '${order.productsCount} SKUs',
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Quantity',
                value: '${order.quantity.toInt()} units',
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Price',
                value: _rupee(order.amount),
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(
                label: 'Total',
                value: _rupee(order.amount),
                highlight: true,
              ),
            ),
            SizedBox(
              width: columnWidth,
              child: _OrderMetaItem(label: 'Notes', value: order.notes),
            ),
          ],
        );
      },
    );
  }
}

class _OrderMetaItem extends StatelessWidget {
  const _OrderMetaItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFEFF), Color(0xFFF6F9FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? const Color(0xFFBBD3FF) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: highlight ? 14.5 : 13,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsTable extends StatelessWidget {
  const _OrderItemsTable({required this.items});

  final List<_OrderLineItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF3F7FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 36,
                    child: Text(
                      'Product',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'SKU',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Price',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'Total',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map(
            (entry) => Column(
              children: [
                Container(
                  color: entry.key.isEven
                      ? Colors.white
                      : const Color(0xFFFAFCFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 36,
                        child: Text(
                          entry.value.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Text(
                          entry.value.sku,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Text(
                          entry.value.quantity.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Text(
                          _rupee(entry.value.unitPrice),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Text(
                          _rupee(entry.value.lineTotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key != items.length - 1) const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryAndAllocateCard extends StatelessWidget {
  const _InventoryAndAllocateCard({
    required this.inventory,
    required this.orders,
    required this.onAllocate,
  });

  final _InventorySummary inventory;
  final List<_OrderViewModel> orders;
  final ValueChanged<_OrderViewModel> onAllocate;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory & Allocate Stock',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _StockTile(
            'Available Stock',
            '${inventory.availableStock} units',
            const Color(0xFF22C55E),
          ),
          const SizedBox(height: 8),
          _StockTile(
            'Reserved Stock',
            '${inventory.reservedStock} units',
            const Color(0xFF2E5BFF),
          ),
          const SizedBox(height: 8),
          _StockTile(
            'Low Stock',
            '${inventory.lowStockSkus} SKUs',
            const Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          Text(
            'Allocate stock to approved orders:',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AllocationRow(
                order: order,
                onAllocate: order.id == null ? null : () => onAllocate(order),
              ),
            ),
          ),
          if (orders.isEmpty)
            const Text(
              'No approved orders waiting for stock allocation.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.order, required this.onAllocate});

  final _OrderViewModel order;
  final VoidCallback? onAllocate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${order.orderId} • ${order.productsCount} SKUs • ${order.quantity.toInt()} units',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: onAllocate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Allocate',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _DispatchSubmit =
    Future<void> Function(
      String orderCode,
      String transportName,
      String dispatchAssignee,
      DateTime dispatchDateTime,
      DateTime expectedDeliveryDateTime,
    );

class _DispatchCard extends StatefulWidget {
  const _DispatchCard({required this.order, required this.onDispatch});

  final _OrderViewModel order;
  final _DispatchSubmit? onDispatch;

  @override
  State<_DispatchCard> createState() => _DispatchCardState();
}

class _DispatchCardState extends State<_DispatchCard> {
  final TextEditingController _orderIdController = TextEditingController();
  final TextEditingController _transportNameController =
      TextEditingController();
  final TextEditingController _dispatchAssigneeController =
      TextEditingController();
  DateTime? _dispatchDateTime;
  DateTime? _expectedDeliveryDateTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _seedFromOrder();
  }

  @override
  void didUpdateWidget(covariant _DispatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.orderId != widget.order.orderId) {
      _seedFromOrder();
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _transportNameController.dispose();
    _dispatchAssigneeController.dispose();
    super.dispose();
  }

  void _seedFromOrder() {
    _orderIdController.text = widget.order.orderId;
    _transportNameController.text = widget.order.transportName == 'Not Assigned'
        ? ''
        : widget.order.transportName;
    _dispatchAssigneeController.text =
        widget.order.dispatchAssignee == 'Not Assigned'
        ? ''
        : widget.order.dispatchAssignee;
    _dispatchDateTime = widget.order.dispatchTime ?? DateTime.now();
    _expectedDeliveryDateTime =
        widget.order.expectedDeliveryTime ??
        _dispatchDateTime!.add(const Duration(days: 1));
  }

  Future<void> _pickDispatchDateTime() async {
    final base = _dispatchDateTime ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _dispatchDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (_expectedDeliveryDateTime == null ||
          _expectedDeliveryDateTime!.isBefore(_dispatchDateTime!)) {
        _expectedDeliveryDateTime = _dispatchDateTime!.add(
          const Duration(days: 1),
        );
      }
    });
  }

  Future<void> _pickExpectedDeliveryDateTime() async {
    final base =
        _expectedDeliveryDateTime ??
        _dispatchDateTime?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _expectedDeliveryDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _dispatchTimeLabel() {
    final value = _dispatchDateTime;
    if (value == null) {
      return 'Select date and time';
    }
    final dd = value.day.toString().padLeft(2, '0');
    final mon = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$dd/$mon/$yyyy  $hh:$mm';
  }

  String _expectedDeliveryTimeLabel() {
    final value = _expectedDeliveryDateTime;
    if (value == null) {
      return 'Select expected delivery';
    }
    final dd = value.day.toString().padLeft(2, '0');
    final mon = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$dd/$mon/$yyyy  $hh:$mm';
  }

  Future<void> _submitDispatch() async {
    if (widget.onDispatch == null || _submitting) {
      return;
    }

    final orderCode = _orderIdController.text.trim();
    final transportName = _transportNameController.text.trim();
    final dispatchAssignee = _dispatchAssigneeController.text.trim();
    final dispatchDateTime = _dispatchDateTime;
    final expectedDeliveryDateTime = _expectedDeliveryDateTime;

    if (orderCode.isEmpty ||
        transportName.isEmpty ||
        dispatchAssignee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter order ID, transport name and dispatch assignee.',
          ),
        ),
      );
      return;
    }

    if (dispatchDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose dispatch time.')),
      );
      return;
    }

    if (expectedDeliveryDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose expected delivery time.')),
      );
      return;
    }

    if (expectedDeliveryDateTime.isBefore(dispatchDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expected delivery must be after dispatch time.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onDispatch!(
        orderCode,
        transportName,
        dispatchAssignee,
        dispatchDateTime,
        expectedDeliveryDateTime,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxFormWidth = MediaQuery.sizeOf(context).width < 900 ? 520.0 : 560.0;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispatch',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign transport, assignee, dispatch time and expected delivery time.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: maxFormWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 500;
                  final gap = 10.0;
                  final fieldWidth = twoCols
                      ? (constraints.maxWidth - gap) / 2
                      : constraints.maxWidth;

                  return Column(
                    children: [
                      Wrap(
                        spacing: gap,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _DispatchTextField(
                              label: 'Order ID',
                              controller: _orderIdController,
                              hintText: 'Type order id',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9\-]'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _DispatchTextField(
                              label: 'Transport',
                              controller: _transportNameController,
                              hintText: 'Type transport name',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9\- ]'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _DispatchTextField(
                              label: 'Assignee',
                              controller: _dispatchAssigneeController,
                              hintText: 'Type dispatch assignee',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[A-Za-z .]"),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _DispatchTimeField(
                              label: 'Date & Time',
                              value: _dispatchTimeLabel(),
                              onTap: _pickDispatchDateTime,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _DispatchTimeField(
                              label: 'Expected Delivery',
                              value: _expectedDeliveryTimeLabel(),
                              onTap: _pickExpectedDeliveryDateTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _submitDispatch,
                          icon: const Icon(Icons.local_shipping_rounded),
                          label: Text(
                            _submitting ? 'Dispatching...' : 'Dispatch Order',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchTextField extends StatelessWidget {
  const _DispatchTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              inputFormatters: inputFormatters,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              decoration:
                  const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ).copyWith(
                    hintText: hintText,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchTimeField extends StatelessWidget {
  const _DispatchTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 98,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.schedule_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard({required this.orders});

  final List<_OrderViewModel> orders;

  @override
  Widget build(BuildContext context) {
    final transitRecords =
        orders.where((o) => o.status == 'In Transit').toList()..sort((a, b) {
          final aTime = a.dispatchTime ?? a.createdAt;
          final bTime = b.dispatchTime ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'In transit orders with dispatch details.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: transitRecords.isEmpty
                ? const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'No in transit orders yet.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    child: SingleChildScrollView(
                      child: Column(
                        children: transitRecords
                            .map(
                              (o) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DeliveryRecordRow(
                                  orderId: o.orderId,
                                  transportName: o.transportName,
                                  dispatchAt: o.dispatchTime,
                                  expectedAt: o.expectedDeliveryTime,
                                  status: o.status,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRecordRow extends StatelessWidget {
  const _DeliveryRecordRow({
    required this.orderId,
    required this.transportName,
    required this.dispatchAt,
    required this.expectedAt,
    required this.status,
  });

  final String orderId;
  final String transportName;
  final DateTime? dispatchAt;
  final DateTime? expectedAt;
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        color: AppColors.surfaceSoft,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 30,
            child: Text(
              orderId,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 30,
            child: Text(
              transportName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              _formatEtaDateTime(expectedAt),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 15,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(
                label: status,
                color: statusColor,
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
String _formatDispatchDateTime(DateTime? value) {
  if (value == null) {
    return 'Not assigned';
  }
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString();
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}

String _formatEtaDateTime(DateTime? value) {
  if (value == null) {
    return 'ETA not set';
  }
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString();
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return 'ETA $dd/$mm/$yyyy $hh:$min';
}

// ignore: unused_element
class _UserManagementCard extends StatelessWidget {
  const _UserManagementCard({required this.stats});

  final _UserStats stats;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Management',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Manage Salesmen, Warehouse Staff and Admin accounts.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _UserStatTile(
            'Salesmen',
            '${stats.salesmen}',
            Icons.groups_rounded,
            const Color(0xFF2E5BFF),
          ),
          const SizedBox(height: 8),
          _UserStatTile(
            'Warehouse Staff',
            '${stats.warehouseStaff}',
            Icons.warehouse_rounded,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 8),
          _UserStatTile(
            'Admins',
            '${stats.admins}',
            Icons.verified_user_rounded,
            const Color(0xFF22C55E),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: const Text('Add User'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserStatTile extends StatelessWidget {
  const _UserStatTile(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ReportsChartsCard extends StatelessWidget {
  const _ReportsChartsCard({required this.data});

  final _ReportSeries data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LineChartCard(
          title: 'Daily Orders',
          subtitle: 'Incoming order trend for the last 12 days',
          values: data.dailyOrders,
          color: AppColors.primary,
          labels: const ['D1', 'D3', 'D5', 'D7', 'D9', 'D12'],
        ),
        const SizedBox(height: 14),
        BarChartCard(
          title: 'Monthly Sales',
          subtitle: 'Revenue performance for the current year (₹ in thousands)',
          values: data.monthlySales,
          labels: const ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'],
          color: const Color(0xFF0EA5E9),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _TopProductsAndNotesCard extends StatelessWidget {
  const _TopProductsAndNotesCard({
    required this.regionSlices,
    required this.topProducts,
  });

  final List<ChartSlice> regionSlices;
  final List<_TopProductData> topProducts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DonutChartCard(
          title: 'Sales by Region',
          subtitle: 'Contribution of each region to total revenue',
          items: regionSlices,
        ),
        const SizedBox(height: 14),
        _TopProductsCard(topProducts: topProducts),
      ],
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.topProducts});

  final List<_TopProductData> topProducts;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Products',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...List.generate(topProducts.length, (index) {
            final p = topProducts[index];
            return Column(
              children: [
                _productRow(
                  context,
                  p.name,
                  '${p.units.toInt()} units',
                  _rupee(p.value),
                ),
                if (index != topProducts.length - 1) const Divider(height: 20),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _productRow(
    BuildContext context,
    String name,
    String qty,
    String value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(qty, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InventorySummary {
  const _InventorySummary({
    required this.availableStock,
    required this.reservedStock,
    required this.lowStockSkus,
  });

  final int availableStock;
  final int reservedStock;
  final int lowStockSkus;
}

class _UserStats {
  const _UserStats({
    required this.salesmen,
    required this.warehouseStaff,
    required this.admins,
  });

  final int salesmen;
  final int warehouseStaff;
  final int admins;
}

class _TopProductData {
  const _TopProductData(this.name, this.units, this.value);

  final String name;
  final double units;
  final double value;
}

class _ReportSeries {
  const _ReportSeries({required this.dailyOrders, required this.monthlySales});

  final List<double> dailyOrders;
  final List<double> monthlySales;
}

class _OrderLineItem {
  const _OrderLineItem({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
}

class _OrderViewModel {
  const _OrderViewModel({
    required this.id,
    required this.orderId,
    required this.salesman,
    required this.shop,
    required this.region,
    required this.createdAt,
    required this.amount,
    required this.status,
    required this.productsCount,
    required this.quantity,
    required this.notes,
    required this.transportName,
    required this.dispatchAssignee,
    required this.driver,
    required this.vehicle,
    required this.dispatchTime,
    required this.expectedDeliveryTime,
    required this.rawProducts,
  });

  final String? id;
  final String orderId;
  final String salesman;
  final String shop;
  final String region;
  final DateTime createdAt;
  final double amount;
  final String status;
  final int productsCount;
  final double quantity;
  final String notes;
  final String transportName;
  final String dispatchAssignee;
  final String driver;
  final String vehicle;
  final DateTime? dispatchTime;
  final DateTime? expectedDeliveryTime;
  final List<Map<String, dynamic>> rawProducts;

  List<_OrderLineItem> get productsForDialog {
    if (rawProducts.isNotEmpty) {
      return List.generate(rawProducts.length, (index) {
        final p = rawProducts[index];
        final qty = _asNum(p['quantity'] ?? 0);
        final total = _asNum(p['total'] ?? p['lineTotal'] ?? 0);
        final price = qty > 0 ? (total / qty).toDouble() : 0.0;
        return _OrderLineItem(
          name: (p['name'] ?? p['productName'] ?? 'Item ${index + 1}')
              .toString(),
          sku: (p['sku'] ?? p['code'] ?? 'SKU-${index + 1}').toString(),
          quantity: qty,
          unitPrice: price,
          lineTotal: total,
        );
      });
    }

    final count = productsCount > 0 ? productsCount : 1;
    final perItemQty = quantity > 0 ? (quantity / count).toDouble() : 1.0;
    final perItemPrice = amount > 0 ? (amount / count).toDouble() : 0.0;

    return List.generate(
      count,
      (index) => _OrderLineItem(
        name: 'Item ${index + 1}',
        sku: 'SKU-${(index + 1).toString().padLeft(3, '0')}',
        quantity: perItemQty,
        unitPrice: perItemPrice,
        lineTotal: perItemQty * perItemPrice,
      ),
    );
  }

  String get timeText {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dispatchText {
    if (dispatchTime == null) {
      return 'Not Assigned';
    }
    final h = dispatchTime!.hour.toString().padLeft(2, '0');
    final m = dispatchTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ignore: unused_element
  factory _OrderViewModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final dispatchRaw = data['dispatchTime'];

    DateTime createdAt = DateTime.now();
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }

    DateTime? dispatchTime;
    if (dispatchRaw is Timestamp) {
      dispatchTime = dispatchRaw.toDate();
    } else if (dispatchRaw is DateTime) {
      dispatchTime = dispatchRaw;
    }

    final productsDynamic = data['products'];
    List<Map<String, dynamic>> products = const [];
    if (productsDynamic is List) {
      products = productsDynamic
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final quantityFromProducts = products.fold<double>(
      0,
      (sum, item) => sum + _asNum(item['quantity'] ?? 0),
    );

    return _OrderViewModel(
      id: doc.id,
      orderId: (data['orderId'] ?? doc.id).toString(),
      salesman: (data['salesmanName'] ?? data['salesman'] ?? 'Unknown')
          .toString(),
      shop: (data['shopName'] ?? data['shop'] ?? 'Unknown Shop').toString(),
      region: (data['region'] ?? 'North').toString(),
      createdAt: createdAt,
      amount: _asNum(data['amount'] ?? data['total'] ?? 0),
      status: _normalizeStatus((data['status'] ?? 'Pending').toString()),
      productsCount: (data['productsCount'] is num)
          ? (data['productsCount'] as num).toInt()
          : (products.isNotEmpty ? products.length : 0),
      quantity: _asNum(data['quantity'] ?? quantityFromProducts),
      notes: (data['notes'] ?? 'No notes').toString(),
      transportName:
          (data['transportName'] ?? data['vehicle'] ?? 'Not Assigned')
              .toString(),
      dispatchAssignee:
          (data['dispatchAssignee'] ?? data['driver'] ?? 'Not Assigned')
              .toString(),
      driver: (data['driver'] ?? 'Not Assigned').toString(),
      vehicle: (data['vehicle'] ?? 'Not Assigned').toString(),
      dispatchTime: dispatchTime,
      expectedDeliveryTime: null,
      rawProducts: products,
    );
  }

  factory _OrderViewModel.fromMap(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final dispatchRaw = data['dispatchTime'];
    final expectedRaw = data['expectedDeliveryTime'];

    DateTime createdAt = DateTime.now();
    if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
    }

    DateTime? dispatchTime;
    if (dispatchRaw is DateTime) {
      dispatchTime = dispatchRaw;
    } else if (dispatchRaw is String) {
      dispatchTime = DateTime.tryParse(dispatchRaw);
    }

    DateTime? expectedDeliveryTime;
    if (expectedRaw is DateTime) {
      expectedDeliveryTime = expectedRaw;
    } else if (expectedRaw is String) {
      expectedDeliveryTime = DateTime.tryParse(expectedRaw);
    }

    final productsDynamic = data['products'];
    List<Map<String, dynamic>> products = const [];
    if (productsDynamic is List) {
      products = productsDynamic
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final quantityFromProducts = products.fold<double>(
      0,
      (sum, item) => sum + _asNum(item['quantity'] ?? 0),
    );

    return _OrderViewModel(
      id: (data['id'] ?? '').toString().isEmpty ? null : data['id'].toString(),
      orderId: (data['orderId'] ?? data['order_code'] ?? 'UNKNOWN').toString(),
      salesman: (data['salesmanName'] ?? data['salesman'] ?? 'Unknown')
          .toString(),
      shop: (data['shopName'] ?? data['shop'] ?? 'Unknown Shop').toString(),
      region: (data['region'] ?? 'North').toString(),
      createdAt: createdAt,
      amount: _asNum(data['amount'] ?? data['total'] ?? 0),
      status: _normalizeStatus((data['status'] ?? 'Pending').toString()),
      productsCount: (data['productsCount'] is num)
          ? (data['productsCount'] as num).toInt()
          : (products.isNotEmpty ? products.length : 0),
      quantity: _asNum(data['quantity'] ?? quantityFromProducts),
      notes: (data['notes'] ?? 'No notes').toString(),
      transportName:
          (data['transportName'] ?? data['vehicle'] ?? 'Not Assigned')
              .toString(),
      dispatchAssignee:
          (data['dispatchAssignee'] ?? data['driver'] ?? 'Not Assigned')
              .toString(),
      driver: (data['driver'] ?? 'Not Assigned').toString(),
      vehicle: (data['vehicle'] ?? 'Not Assigned').toString(),
      dispatchTime: dispatchTime,
      expectedDeliveryTime: expectedDeliveryTime,
      rawProducts: products,
    );
  }
}

final List<_OrderViewModel> _sampleOrders = [
  _OrderViewModel(
    id: null,
    orderId: 'ORD-21051',
    salesman: 'Rajesh',
    shop: 'Sharma Store',
    region: 'North',
    createdAt: DateTime.now().subtract(const Duration(minutes: 24)),
    amount: 12450,
    status: 'Pending',
    productsCount: 5,
    quantity: 58,
    notes: 'Handle fragile cartons on top rack.',
    transportName: 'Not Assigned',
    dispatchAssignee: 'Not Assigned',
    driver: 'Not Assigned',
    vehicle: 'Not Assigned',
    dispatchTime: null,
    expectedDeliveryTime: null,
    rawProducts: const [],
  ),
  _OrderViewModel(
    id: null,
    orderId: 'ORD-21052',
    salesman: 'Anoop',
    shop: 'Royal Mart',
    region: 'West',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    amount: 7830,
    status: 'Pending',
    productsCount: 4,
    quantity: 44,
    notes: 'Deliver before noon.',
    transportName: 'Not Assigned',
    dispatchAssignee: 'Not Assigned',
    driver: 'Not Assigned',
    vehicle: 'Not Assigned',
    dispatchTime: null,
    expectedDeliveryTime: null,
    rawProducts: const [],
  ),
  _OrderViewModel(
    id: null,
    orderId: 'ORD-21053',
    salesman: 'Vivek',
    shop: 'City Bazaar',
    region: 'East',
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    amount: 5620,
    status: 'Approved',
    productsCount: 6,
    quantity: 76,
    notes: 'Customer requested sealed packs only.',
    transportName: 'Not Assigned',
    dispatchAssignee: 'Not Assigned',
    driver: 'Not Assigned',
    vehicle: 'Not Assigned',
    dispatchTime: null,
    expectedDeliveryTime: null,
    rawProducts: const [],
  ),
  _OrderViewModel(
    id: null,
    orderId: 'ORD-21054',
    salesman: 'Kiran',
    shop: 'Kumar Traders',
    region: 'South',
    createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
    amount: 18220,
    status: 'Ready to Dispatch',
    productsCount: 8,
    quantity: 136,
    notes: 'Dispatch with insurance invoice copy.',
    transportName: 'TN-37-AB-1205',
    dispatchAssignee: 'Ramesh Kumar',
    driver: 'Ramesh Kumar',
    vehicle: 'TN-37-AB-1205',
    dispatchTime: DateTime.now().subtract(const Duration(minutes: 2)),
    expectedDeliveryTime: DateTime.now().add(const Duration(hours: 22)),
    rawProducts: const [],
  ),
];

Color _statusColor(String status) {
  switch (status) {
    case 'Pending':
      return const Color(0xFFFFB547);
    case 'Approved':
      return const Color(0xFF22C55E);
    case 'Ready to Dispatch':
      return const Color(0xFF0EA5E9);
    case 'In Transit':
      return const Color(0xFF2E5BFF);
    case 'Delivered':
      return const Color(0xFF22C55E);
    case 'Rejected':
      return const Color(0xFFEF4444);
    default:
      return AppColors.textMuted;
  }
}

String _normalizeStatus(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('ready')) return 'Ready to Dispatch';
  if (value.contains('process') || value.contains('approve')) return 'Approved';
  if (value.contains('transit')) return 'In Transit';
  if (value.contains('deliver')) return 'Delivered';
  if (value.contains('reject')) return 'Rejected';
  if (value.contains('pending') || value.contains('new')) return 'Pending';
  return 'Pending';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

double _asNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _rupee(double value) {
  final rounded = value.round().toString();
  final chars = rounded.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
      out.add(',');
    }
    out.add(chars[i]);
  }
  return '₹ ${out.reversed.join()}';
}
