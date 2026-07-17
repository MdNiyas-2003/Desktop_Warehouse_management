import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class SalesmenScreen extends StatelessWidget {
  const SalesmenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('salesmen'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Salesman Management',
            subtitle: 'Track field team performance, territory, and route activity.',
            action: const ActionButton(label: 'Add Salesman', icon: Icons.person_add_rounded, primary: true),
          ),
          const SizedBox(height: 18),
          SimpleTable(
            headers: const ['Name', 'Mobile', 'Region', 'Email', 'Status', 'Action'],
            rows: const [
              [TableTextCell('Rajesh Kumar'), TableTextCell('9876543200'), TableTextCell('North'), TableTextCell('rajesh@example.com'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('Sanjay Patel'), TableTextCell('9876543201'), TableTextCell('South'), TableTextCell('sanjay@example.com'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('Amit Verma'), TableTextCell('9876543202'), TableTextCell('East'), TableTextCell('amit@example.com'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('Vikram Singh'), TableTextCell('9876543203'), TableTextCell('West'), TableTextCell('vikram@example.com'), _StatusCell('Inactive', AppColors.danger), _RowActions()],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell(this.label, this.color);

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
      ],
    );
  }
}