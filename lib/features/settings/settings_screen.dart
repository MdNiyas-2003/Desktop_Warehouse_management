import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Settings',
            subtitle: 'Configure company details, tax settings, and backup preferences.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 1100;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: twoColumn ? (constraints.maxWidth - 16) * 0.62 : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Company Details', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 18),
                          const _Field(label: 'Company Name', hint: AppConstants.companyName),
                          const SizedBox(height: 14),
                          const _Field(label: 'Address', hint: '123 Business Park, MG Road, Delhi - 110001'),
                          const SizedBox(height: 14),
                          const _Field(label: 'Email', hint: 'info@saleserp.com'),
                          const SizedBox(height: 14),
                          const _Field(label: 'Website', hint: 'www.saleserp.com'),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: twoColumn ? (constraints.maxWidth - 16) * 0.38 : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: AppColors.panelGradient,
                                    ),
                                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 32),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    AppConstants.appName,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  Text('Private Limited', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SettingRow(label: 'Tax enabled', value: 'GST / VAT ready'),
                          const _SettingRow(label: 'Backup frequency', value: 'Daily at 11:30 PM'),
                          const _SettingRow(label: 'Theme mode', value: 'Premium desktop light'),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Change Logo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(decoration: InputDecoration(hintText: hint)),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }
}