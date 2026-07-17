import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Profile & Settings',
            subtitle: 'Manage profile information, password, and security preferences.',
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
                    width: twoColumn ? (constraints.maxWidth - 16) * 0.34 : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          const AppAvatar(label: 'Admin User', size: 86),
                          const SizedBox(height: 18),
                          Text('Admin User', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('admin@example.com', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          const StatusBadge(label: 'Super Admin', color: AppColors.primary),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 12),
                          const _MiniStat(label: 'Mobile', value: '9876543210'),
                          const SizedBox(height: 12),
                          const _MiniStat(label: 'Location', value: 'Bengaluru, India'),
                          const SizedBox(height: 12),
                          const _MiniStat(label: 'Last login', value: 'Today, 09:40 AM'),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Change Photo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: twoColumn ? (constraints.maxWidth - 16) * 0.64 : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profile Information', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final formWidth = constraints.maxWidth >= 700 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(width: formWidth, child: const _Field(label: 'Full Name', hint: 'Admin User')),
                                  SizedBox(width: formWidth, child: const _Field(label: 'Email', hint: 'admin@example.com')),
                                  SizedBox(width: formWidth, child: const _Field(label: 'Mobile', hint: '9876543210')),
                                  SizedBox(width: formWidth, child: const _Field(label: 'Username', hint: 'admin')),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          const _Field(label: 'Address', hint: '123 Business Park, MG Road, Delhi'),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {},
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Update Profile'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () {},
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Change Password'),
                                ),
                              ),
                            ],
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
      ],
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