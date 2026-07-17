import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('users'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'User Management',
            subtitle: 'Create platform access for admins, warehouse users, and staff roles.',
            action: const ActionButton(label: 'Add User', icon: Icons.person_add_alt_rounded, primary: true),
          ),
          const SizedBox(height: 18),
          SimpleTable(
            headers: const ['Username', 'Name', 'Role', 'Status', 'Action'],
            rows: const [
              [TableTextCell('admin'), TableTextCell('System Admin'), TableTextCell('Super Admin'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('warehouse1'), TableTextCell('Suresh Yadav'), TableTextCell('Warehouse Staff'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('manager1'), TableTextCell('Pooja Sharma'), TableTextCell('Sales Manager'), _StatusCell('Active', AppColors.success), _RowActions()],
              [TableTextCell('staff1'), TableTextCell('Rohit Gupta'), TableTextCell('Warehouse Staff'), _StatusCell('Active', AppColors.success), _RowActions()],
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
        Icon(Icons.lock_outline_rounded, size: 18),
      ],
    );
  }
}