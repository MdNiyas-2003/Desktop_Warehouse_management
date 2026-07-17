import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('products'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Product Management',
            subtitle: 'Maintain stock keeping units, categories, pricing, and warehouse quantities.',
            action: const ActionButton(label: 'Add Product', icon: Icons.add_rounded, primary: true),
          ),
          const SizedBox(height: 18),
          SimpleTable(
            headers: const ['Product Name', 'Category', 'SKU', 'Price', 'Stock', 'Action'],
            rows: const [
              [
                TableTextCell('Tata Tea 1kg'),
                TableTextCell('Beverages'),
                TableTextCell('PROD-1001'),
                TableTextCell('₹ 280.00'),
                TableTextCell('120'),
                _RowActions(),
              ],
              [
                TableTextCell('Ashirvad Atta 5kg'),
                TableTextCell('Food'),
                TableTextCell('PROD-1002'),
                TableTextCell('₹ 320.00'),
                TableTextCell('80'),
                _RowActions(),
              ],
              [
                TableTextCell('Surf Excel 1kg'),
                TableTextCell('Personal Care'),
                TableTextCell('PROD-1003'),
                TableTextCell('₹ 160.00'),
                TableTextCell('150'),
                _RowActions(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.edit_outlined, size: 18),
        SizedBox(width: 10),
        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
      ],
    );
  }
}