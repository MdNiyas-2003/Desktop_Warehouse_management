import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'WAREHOUSE';
  static const String appSubtitle = 'Field Sales & Warehouse Management System';
  static const String companyName = 'Sales ERP Private Limited';
  static const String adminName = 'Admin User';
  static const String adminRole = 'Super Admin';
}

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.index,
  });

  final String label;
  final IconData icon;
  final int index;
}

const List<AppNavItem> appNavItems = [
  AppNavItem(label: 'Dashboard', icon: Icons.space_dashboard_rounded, index: 0),
  AppNavItem(label: 'Sales', icon: Icons.query_stats_rounded, index: 13),
  AppNavItem(label: 'Orders', icon: Icons.receipt_long_rounded, index: 1),
  // AppNavItem(label: 'Products', icon: Icons.inventory_2_rounded, index: 2),
  // AppNavItem(label: 'Inventory', icon: Icons.warehouse_rounded, index: 3),
  AppNavItem(label: 'Shops', icon: Icons.storefront_rounded, index: 4),
  // AppNavItem(label: 'Salesmen', icon: Icons.groups_rounded, index: 5),
  AppNavItem(label: 'Warehouse', icon: Icons.local_shipping_rounded, index: 6),
  AppNavItem(label: 'Reports', icon: Icons.query_stats_rounded, index: 7),
  // AppNavItem(label: 'Users', icon: Icons.badge_rounded, index: 8),
  // AppNavItem(label: 'Settings', icon: Icons.settings_rounded, index: 9),
];
