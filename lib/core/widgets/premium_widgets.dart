import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, this.hintText = 'Search anything...'});

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 4),
                Text(
                  delta,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
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

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppColors.primary : AppColors.surface;
    final foreground = primary ? Colors.white : AppColors.text;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: primary ? null : const BorderSide(color: AppColors.border),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.label, this.size = 38});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1))
        .join();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.panelGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onSelected,
    this.compact = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 8 : 10,
      runSpacing: compact ? 8 : 10,
      children: List.generate(labels.length, (index) {
        final isSelected = index == selectedIndex;
        return GestureDetector(
          onTap: onSelected == null ? null : () => onSelected!(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              labels[index],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.white : AppColors.text,
                fontSize: compact ? 12 : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class SimpleTable extends StatelessWidget {
  const SimpleTable({
    super.key,
    required this.headers,
    required this.rows,
    this.compact = false,
    this.columnFlexes,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final bool compact;
  final List<int>? columnFlexes;

  int _flexAt(int index) {
    if (columnFlexes == null || index >= columnFlexes!.length) {
      return 1;
    }
    final value = columnFlexes![index];
    return value > 0 ? value : 1;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              compact ? 14 : 18,
              compact ? 16 : 20,
              compact ? 10 : 14,
            ),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  Expanded(
                    flex: _flexAt(i),
                    child: Text(
                      headers[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontSize: compact ? 12 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map(
            (row) => Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 20,
                    vertical: compact ? 12 : 16,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < row.length; i++)
                        Expanded(flex: _flexAt(i), child: row[i]),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TableTextCell extends StatelessWidget {
  const TableTextCell(
    this.title, {
    super.key,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              (compact
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12.5 : null,
                  ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: compact ? 12 : null),
          ),
        ],
      ],
    );
  }
}

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class InfoListCard extends StatelessWidget {
  const InfoListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          ...items,
        ],
      ),
    );
  }
}
