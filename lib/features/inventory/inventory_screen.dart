import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('inventory'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Inventory / Stock',
            subtitle: 'Monitor stock position across all warehouses with live alerts.',
            action: const ActionButton(label: 'Stock Audit', icon: Icons.inventory_2_rounded, primary: true),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1150 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  MetricCard(label: 'Total Stock Items', value: '350', delta: 'Across warehouses', icon: Icons.inventory_2_rounded, color: AppColors.primary),
                  MetricCard(label: 'Low Stock Items', value: '25', delta: 'Needs replenishment', icon: Icons.warning_amber_rounded, color: AppColors.warning),
                  MetricCard(label: 'Out of Stock', value: '5', delta: 'Urgent re-order', icon: Icons.remove_circle_outline_rounded, color: AppColors.danger),
                  MetricCard(label: 'Total Stock Value', value: '₹ 8,45,000', delta: 'Inventory valuation', icon: Icons.paid_rounded, color: AppColors.success),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SimpleTable(
            headers: const ['Product Name', 'SKU', 'Warehouse Stock', 'Available Stock', 'Status', 'Action'],
            rows: const [
              [
                TableTextCell('Tata Tea 1kg'),
                TableTextCell('PROD-1001'),
                TableTextCell('200'),
                TableTextCell('120'),
                _StockBadge('In Stock', AppColors.success),
                _RowActions(),
              ],
              [
                TableTextCell('Ashirvad Atta 5kg'),
                TableTextCell('PROD-1002'),
                TableTextCell('120'),
                TableTextCell('80'),
                _StockBadge('In Stock', AppColors.success),
                _RowActions(),
              ],
              [
                TableTextCell('Surf Excel 1kg'),
                TableTextCell('PROD-1003'),
                TableTextCell('40'),
                TableTextCell('10'),
                _StockBadge('Low Stock', AppColors.warning),
                _RowActions(),
              ],
              [
                TableTextCell('Coca Cola 2L'),
                TableTextCell('PROD-1004'),
                TableTextCell('0'),
                TableTextCell('0'),
                _StockBadge('Out of Stock', AppColors.danger),
                _RowActions(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => StatusBadge(label: label, color: color);
}

class _RowActions extends StatelessWidget {
  const _RowActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.edit_outlined, size: 18),
        SizedBox(width: 10),
        Icon(Icons.visibility_outlined, size: 18),
        SizedBox(width: 10),
        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
      ],
    );
  }
}