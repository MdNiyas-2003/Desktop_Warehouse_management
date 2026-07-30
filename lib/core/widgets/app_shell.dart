import 'package:desktop/features/accounts/ledger_screen.dart';
import 'package:desktop/features/accounts/payment_entry/payment_entry_screen.dart';
import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/salesmen/salesmen_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shops/shops_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/warehouse/warehouse_screen.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'premium_widgets.dart';

class DesktopEntry extends StatefulWidget {
  const DesktopEntry({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<DesktopEntry> createState() => _DesktopEntryState();
}

class _DesktopEntryState extends State<DesktopEntry> {
  int _selectedIndex = 0;
  int _openOrderDialogSignal = 0;
  int _openCustomerDialogSignal = 0;

  String _titleForIndex(int index) {
    switch (index) {
      case 10:
        return "Payment Entry";

      case 11:
        return "Ledger";

      default:
        for (final item in appNavItems) {
          if (item.index == index) {
            return item.label;
          }
        }
        return "Dashboard";
    }
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return OrdersScreen(openCreateSignal: _openOrderDialogSignal);
      case 2:
        return const ProductsScreen();
      case 3:
        return const InventoryScreen();
      case 4:
        return ShopsScreen(openCreateSignal: _openCustomerDialogSignal);
      case 5:
        return const SalesmenScreen();
      case 6:
        return const WarehouseScreen();
      case 7:
        return const ReportsScreen();
      case 8:
        return const UsersScreen();
      case 9:
        return const SettingsScreen();
      case 10:
        return const PaymentEntryScreen();
      case 11:
        return const LedgerScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _openCreateOrderFromQuickAction() {
    setState(() {
      _selectedIndex = 1;
      _openOrderDialogSignal++;
    });
  }

  void _openCreateCustomerFromQuickAction() {
    setState(() {
      _selectedIndex = 4;
      _openCustomerDialogSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            onSelected: (value) => setState(() => _selectedIndex = value),
            onNewOrderTap: _openCreateOrderFromQuickAction,
            onCreateCustomerTap: _openCreateCustomerFromQuickAction,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _titleForIndex(_selectedIndex),
                  onLogout: widget.onLogout,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topLeft,
                        children: <Widget>[...previousChildren, ?currentChild],
                      );
                    },
                    child: _screenForIndex(_selectedIndex),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    Key? key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onNewOrderTap,
    required this.onCreateCustomerTap,
  }) : super(key: key);

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewOrderTap;
  final VoidCallback onCreateCustomerTap;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _accountsExpanded = false;
  Widget _subMenu(String title, IconData icon, int index) {
    final selected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 12,
          color: selected ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 11,
          ),
        ),
        onTap: () => widget.onSelected(index),
      ),
    );
  }

  Widget _buildAccountsMenu() {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () {
              setState(() {
                _accountsExpanded = !_accountsExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      "Accounts",
                      style: TextStyle(
                        color: Color.fromARGB(179, 232, 231, 231),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _accountsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _accountsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              _subMenu("Payment Entry", Icons.payments, 10),
              _subMenu("Ledger", Icons.receipt_long, 11),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B234F), Color(0xFF081A3E), Color(0xFF06122A)],
        ),
      ),
      child: Column(
        children: [
          // ---------- Logo ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3D86FF), Color(0xFF255AE7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),

          // ---------- Main menu ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
       Expanded(
  child: Scrollbar(
    thumbVisibility: true,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [

        ...appNavItems.map((item) {
          final selected = item.index == widget.selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => widget.onSelected(item.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2F6FFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: selected
                            ? Colors.white
                            : Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),


        _buildAccountsMenu(),

      ],
    ),
  ),
),
          // const Spacer(),

          // ---------- Quick actions ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  _QuickActionTile(
                    icon: Icons.add_box_outlined,
                    label: 'New Order',
                    onTap: widget.onNewOrderTap,
                  ),
                  const SizedBox(height: 5),
                  _QuickActionTile(
                    icon: Icons.storefront_outlined,
                    label: 'Create Customer',
                    onTap: widget.onCreateCustomerTap,
                  ),
                  const SizedBox(height: 5),
                  const _QuickActionTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Create Dispatch',
                  ),
                ],
              ),
            ),
          ),

          // ---------- Org switcher ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3D86FF), Color(0xFF255AE7)],
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ABC Distributors',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'FY 2024-25',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.unfold_more_rounded,
                        color: Colors.white38,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 13.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0B1020),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Container(
          //   width: 30,
          //   height: 30,
          //   decoration: BoxDecoration(
          //     color: AppColors.surfaceSoft,
          //     borderRadius: BorderRadius.circular(9),
          //     border: Border.all(color: AppColors.border),
          //   ),
          //   // child: const Icon(Icons.menu_rounded, size: 16),
          // ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 300, child: SearchField(hintText: 'Search...')),
          const SizedBox(width: 10),
          _IconBubble(icon: Icons.notifications_none_rounded, hasDot: true),
          const SizedBox(width: 8),
          const _IconBubble(icon: Icons.fullscreen_rounded),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            color: Colors.white,
            tooltip: 'Admin menu',
            onSelected: (value) {
              if (value == 'logout') {
                onLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const AppAvatar(label: AppConstants.adminName, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.adminName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.8,
                        ),
                      ),
                      Text(
                        AppConstants.adminRole,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, this.hasDot = false});

  final IconData icon;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 17),
        ),
        if (hasDot)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
