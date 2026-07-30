import 'package:flutter/material.dart';

class AccountsDashboardScreen extends StatelessWidget {
  const AccountsDashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: const [
                Text(
                  "Accounts",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Row(
              children: const [
                Expanded(
                  child: _SummaryCard(
                    title: "Today's Collection",
                    value: "₹0",
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _SummaryCard(
                    title: "Receivables",
                    value: "₹0",
                    icon: Icons.account_balance_wallet,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _SummaryCard(
                    title: "Payables",
                    value: "₹0",
                    icon: Icons.money_off,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.7,
                children: [
                  _MenuCard(
                    title: "Payment Entry",
                    icon: Icons.payments,
                    onTap: () => onNavigate(11),
                  ),

                  _MenuCard(title: "Receipt Voucher", icon: Icons.receipt),

                  _MenuCard(title: "Payment Voucher", icon: Icons.credit_card),

                  _MenuCard(title: "Customer Ledger", icon: Icons.people),

                  _MenuCard(title: "Supplier Ledger", icon: Icons.business),

                  _MenuCard(title: "Trial Balance", icon: Icons.balance),

                  _MenuCard(title: "Profit & Loss", icon: Icons.trending_up),

                  _MenuCard(title: "Balance Sheet", icon: Icons.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: Colors.indigo),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
