import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final BackendApi _api = BackendApi();
  late Future<_ReportsData> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportsData> _load() async {
    final ordersRaw = await _api.getOrders();
    final customersRaw = await _api.getCustomers();

    final regionByShopId = <String, String>{};
    for (final c in customersRaw) {
      final id = (c['id'] ?? '').toString();
      final region = (c['region'] ?? '').toString().trim();
      if (id.isNotEmpty) {
        regionByShopId[id] = region.isEmpty ? 'Unassigned' : region;
      }
    }

    final orders = ordersRaw.map(_ReportOrder.fromMap).toList();
    return _ReportsData.compute(orders, regionByShopId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

 Future<void> _exportPdf(_ReportsData data) async {
  setState(() => _exporting = true);
  try {
    final doc = _buildReportPdf(data);
    final bytes = await doc.save();

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/sales_report_$stamp.pdf');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF saved to ${file.path}'),
        action: SnackBarAction(
          label: 'Open Folder',
          onPressed: () => _openContainingFolder(file.path),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not export PDF: $e')),
    );
  } finally {
    if (mounted) setState(() => _exporting = false);
  }
}

Future<void> _exportCsv(_ReportsData data) async {
  setState(() => _exporting = true);
  try {
    final csv = _buildReportCsv(data);

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/sales_report_$stamp.csv');
    await file.writeAsString(csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV saved to ${file.path}'),
        action: SnackBarAction(
          label: 'Open Folder',
          onPressed: () => _openContainingFolder(file.path),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not export CSV: $e')),
    );
  } finally {
    if (mounted) setState(() => _exporting = false);
  }
}

Future<void> _openContainingFolder(String filePath) async {
  try {
    final dirPath = File(filePath).parent.path;
    if (Platform.isWindows) {
      await Process.run('explorer', [dirPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dirPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dirPath]);
    }
  } catch (_) {
    // Silently ignore — the SnackBar already showed the path.
  }
}

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('reports'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<_ReportsData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return _ReportsHeader(
                busy: _exporting,
                onRefresh: _refresh,
                onExportPdf: data == null ? null : () => _exportPdf(data),
                onExportCsv: data == null ? null : () => _exportCsv(data),
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<_ReportsData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ReportsLoadingState();
              }
              if (snapshot.hasError) {
                return _ReportsErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              final data = snapshot.data!;
              if (data.orders.isEmpty) {
                return const _ReportsEmptyState();
              }
              return _ReportsBody(data: data);
            },
          ),
        ],
      ),
    );
  }
}

// ---------- Header ----------

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.busy,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onExportCsv,
  });

  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0E2557), Color(0xFF1D56C3)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A1D56C3),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live sales, product, and region analytics from your order data.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: PopupMenuButton<String>(
              enabled: !busy && (onExportPdf != null || onExportCsv != null),
              tooltip: 'Export',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'pdf') onExportPdf?.call();
                if (value == 'csv') onExportCsv?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 17, color: Color(0xFF1D56C3)),
                      SizedBox(width: 10),
                      Text('Export as PDF'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_rounded, size: 17, color: Color(0xFF1D56C3)),
                      SizedBox(width: 10),
                      Text('Export as CSV'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.download_rounded, size: 16, color: Color(0xFF1D56C3)),
                    const SizedBox(width: 8),
                    Text(
                      busy ? 'Exporting…' : 'Export',
                      style: const TextStyle(
                        color: Color(0xFF1D56C3),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Body ----------

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.data});

  final _ReportsData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 1200;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: twoColumn ? (constraints.maxWidth - 16) * 0.66 : constraints.maxWidth,
                  child: _PremiumBarChartCard(
                    title: 'Daily Sales',
                    subtitle: 'Order value for the last 7 days',
                    values: data.dailySales,
                    labels: data.dailyLabels,
                    accent: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: twoColumn ? (constraints.maxWidth - 16) * 0.32 : constraints.maxWidth,
                  child: _PremiumDonutChartCard(
                    title: 'Region Mix',
                    subtitle: 'Order value contribution by region',
                    items: data.regionMix
                        .map((r) => _DonutSlice(r.name, r.percent, r.color))
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 1;
            final spacing = 16.0;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    label: 'Sales This Month',
                    value: _rupee(data.salesThisMonth),
                    delta: data.monthDeltaLabel,
                    icon: Icons.paid_rounded,
                    color: AppColors.primary,
                    positive: data.monthDeltaLabel.trimLeft().startsWith('+'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    label: 'Top Selling Product',
                    value: data.topProductName,
                    delta: '${data.topProductUnits.toStringAsFixed(0)} units sold',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    label: 'Rejected Orders',
                    value: '${data.rejectedOrders}',
                    delta: '${data.rejectedRate.toStringAsFixed(1)}% of total orders',
                    icon: Icons.replay_rounded,
                    color: data.rejectedOrders == 0 ? AppColors.success : AppColors.danger,
                    positive: data.rejectedOrders == 0,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _ReportCardShell(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChartHeader(
                title: 'Top Orders by Value',
                subtitle: '${data.orders.length} orders total',
                icon: Icons.leaderboard_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _TopOrdersTable(orders: data.topOrders),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopOrdersTable extends StatelessWidget {
  const _TopOrdersTable({required this.orders});

  final List<_ReportOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF4F7FE),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 14, child: _HeaderText('Order ID')),
                Expanded(flex: 22, child: _HeaderText('Shop')),
                Expanded(flex: 16, child: _HeaderText('Salesman')),
                Expanded(flex: 14, child: _HeaderText('Amount')),
                Expanded(flex: 14, child: _HeaderText('Status')),
              ],
            ),
          ),
          ...List.generate(orders.length, (i) {
            final o = orders[i];
            return Container(
              color: i.isEven ? Colors.white : const Color(0xFFFAFBFF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 14, child: _CellText(o.orderId)),
                  Expanded(flex: 22, child: _CellText(o.shop)),
                  Expanded(flex: 16, child: _CellText(o.salesman)),
                  Expanded(flex: 14, child: _CellText(_rupee(o.amount))),
                  Expanded(
                    flex: 14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _reportStatusColor(o.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          o.status,
                          style: TextStyle(
                            color: _reportStatusColor(o.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          color: Color(0xFF6C7A94),
        ),
      );
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF29344A),
        ),
      );
}

// ---------- States ----------

class _ReportsLoadingState extends StatelessWidget {
  const _ReportsLoadingState();
  @override
  Widget build(BuildContext context) {
    return _ReportCardShell(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
            SizedBox(height: 14),
            Text('Crunching the latest order data…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return _ReportCardShell(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Unable to load reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState();
  @override
  Widget build(BuildContext context) {
    return _ReportCardShell(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insert_chart_outlined_rounded, size: 34, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('No orders yet — reports will populate once orders come in.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

// ---------- Shared card shell + chart header ----------

class _ReportCardShell extends StatelessWidget {
  const _ReportCardShell({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECF6)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A102A62), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF10203E))),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Bar chart ----------

class _PremiumBarChartCard extends StatelessWidget {
  const _PremiumBarChartCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final List<double> values;
  final List<String> labels;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

    return _ReportCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(title: title, subtitle: subtitle, icon: Icons.bar_chart_rounded, color: accent),
          const SizedBox(height: 22),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(values.length, (i) {
                final v = values[i];
                final fraction = maxValue == 0 ? 0.0 : (v / maxValue).clamp(0.04, 1.0);
                final isMax = v == maxValue && v > 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _compactNumber(v),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isMax ? accent : const Color(0xFF8592AB),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Container(
                        width: 30,
                        height: 140 * value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isMax
                                ? [accent, accent.withValues(alpha: 0.6)]
                                : [accent.withValues(alpha: 0.32), accent.withValues(alpha: 0.12)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(labels[i], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Donut chart ----------

class _DonutSlice {
  const _DonutSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _PremiumDonutChartCard extends StatelessWidget {
  const _PremiumDonutChartCard({required this.title, required this.subtitle, required this.items});
  final String title;
  final String subtitle;
  final List<_DonutSlice> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, i) => sum + i.value);

    return _ReportCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(title: title, subtitle: subtitle, icon: Icons.donut_large_rounded, color: AppColors.primary),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No data available', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
            )
          else ...[
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => CustomPaint(
                        size: const Size(150, 150),
                        painter: _DonutPainter(items: items, total: total, progress: value),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_compactNumber(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF10203E))),
                        const Text('Total', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Column(
              children: items.map((slice) {
                final pct = total == 0 ? 0.0 : (slice.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
                      const SizedBox(width: 9),
                      Expanded(child: Text(slice.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF29344A)))),
                      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: slice.color)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.items, required this.total, required this.progress});
  final List<_DonutSlice> items;
  final double total;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 16.0;
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = const Color(0xFFEEF2FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (final slice in items) {
      final sweep = (slice.value / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle + 0.025, (sweep - 0.025).clamp(0, 2 * math.pi), false, paint);
      startAngle += (slice.value / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.items != items;
}

// ---------- Metric card ----------

class _PremiumMetricCard extends StatelessWidget {
  const _PremiumMetricCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
    this.positive = false,
  });
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return _ReportCardShell(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 22, color: color),
              ),
              const Spacer(),
              if (positive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.trending_up_rounded, size: 15, color: Color(0xFF16A34A)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF10203E), letterSpacing: -0.4),
          ),
          const SizedBox(height: 7),
          Text(delta, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: positive ? const Color(0xFF16A34A) : AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ---------- Data model & aggregation ----------

class _ReportOrder {
  const _ReportOrder({
    required this.orderId,
    required this.shopId,
    required this.shop,
    required this.salesman,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.products,
  });

  final String orderId;
  final String shopId;
  final String shop;
  final String salesman;
  final double amount;
  final String status;
  final DateTime createdAt;
  final List<Map<String, dynamic>> products;

  factory _ReportOrder.fromMap(Map<String, dynamic> data) {
    final createdRaw = data['createdAt'];
    DateTime created = DateTime.now();
    if (createdRaw is DateTime) {
      created = createdRaw;
    } else if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw) ?? created;
    }

    final dynamic productsDynamic = data['products'];
    final products = productsDynamic is List
        ? productsDynamic.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return _ReportOrder(
      orderId: (data['orderId'] ?? '').toString(),
      shopId: (data['shopId'] ?? '').toString(),
      shop: (data['shopName'] ?? data['shop'] ?? 'Unknown Shop').toString(),
      salesman: (data['salesmanName'] ?? data['salesman'] ?? 'Unknown').toString(),
      amount: _asNum(data['amount'] ?? data['total'] ?? 0),
      status: (data['status'] ?? 'Pending').toString(),
      createdAt: created,
      products: products,
    );
  }
}

class _RegionSlice {
  const _RegionSlice(this.name, this.percent, this.color);
  final String name;
  final double percent;
  final Color color;
}

class _ReportsData {
  const _ReportsData({
    required this.orders,
    required this.dailySales,
    required this.dailyLabels,
    required this.salesThisMonth,
    required this.monthDeltaLabel,
    required this.topProductName,
    required this.topProductUnits,
    required this.rejectedOrders,
    required this.rejectedRate,
    required this.regionMix,
    required this.topOrders,
  });

  final List<_ReportOrder> orders;
  final List<double> dailySales;
  final List<String> dailyLabels;
  final double salesThisMonth;
  final String monthDeltaLabel;
  final String topProductName;
  final double topProductUnits;
  final int rejectedOrders;
  final double rejectedRate;
  final List<_RegionSlice> regionMix;
  final List<_ReportOrder> topOrders;

  static _ReportsData compute(List<_ReportOrder> orders, Map<String, String> regionByShopId) {
    if (orders.isEmpty) {
      return const _ReportsData(
        orders: [],
        dailySales: [0, 0, 0, 0, 0, 0, 0],
        dailyLabels: ['', '', '', '', '', '', ''],
        salesThisMonth: 0,
        monthDeltaLabel: 'No data yet',
        topProductName: '—',
        topProductUnits: 0,
        rejectedOrders: 0,
        rejectedRate: 0,
        regionMix: [],
        topOrders: [],
      );
    }

    const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final dailySales = List<double>.filled(7, 0);
    final dailyLabels = days.map((d) => weekdayShort[d.weekday - 1]).toList();

    for (final o in orders) {
      final d = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
      final idx = days.indexWhere((day) => day == d);
      if (idx != -1) dailySales[idx] += o.amount;
    }

    final thisMonthOrders = orders.where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month);
    final salesThisMonth = thisMonthOrders.fold<double>(0, (sum, o) => sum + o.amount);

    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthOrders = orders.where((o) => o.createdAt.year == lastMonthDate.year && o.createdAt.month == lastMonthDate.month);
    final salesLastMonth = lastMonthOrders.fold<double>(0, (sum, o) => sum + o.amount);

    String monthDeltaLabel;
    if (salesLastMonth <= 0) {
      monthDeltaLabel = salesThisMonth > 0 ? 'New activity this month' : 'No orders yet this month';
    } else {
      final pct = ((salesThisMonth - salesLastMonth) / salesLastMonth) * 100;
      final sign = pct >= 0 ? '+' : '';
      monthDeltaLabel = '$sign${pct.toStringAsFixed(1)}% vs last month';
    }

    final productQty = <String, double>{};
    for (final o in orders) {
      for (final p in o.products) {
        final name = (p['name'] ?? p['productName'] ?? 'Item').toString();
        final qty = _asNum(p['quantity'] ?? 0);
        productQty[name] = (productQty[name] ?? 0) + qty;
      }
    }
    String topProductName = '—';
    double topProductUnits = 0;
    productQty.forEach((name, qty) {
      if (qty > topProductUnits) {
        topProductUnits = qty;
        topProductName = name;
      }
    });

    final rejectedOrders = orders.where((o) => o.status == 'Rejected').length;
    final rejectedRate = (rejectedOrders / orders.length) * 100;

    final regionAmount = <String, double>{};
    for (final o in orders) {
      final region = regionByShopId[o.shopId] ?? 'Unassigned';
      regionAmount[region] = (regionAmount[region] ?? 0) + o.amount;
    }
    final totalAmount = regionAmount.values.fold<double>(0, (sum, v) => sum + v);
    const palette = [
      AppColors.primary,
      Color(0xFF6C7AFF),
      AppColors.accent,
      AppColors.success,
      Color(0xFFEF8A3D),
      Color(0xFF9B7BFF),
    ];
    final regionEntries = regionAmount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final regionMix = <_RegionSlice>[];
    for (var i = 0; i < regionEntries.length; i++) {
      final entry = regionEntries[i];
      final percent = totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0.0;
      regionMix.add(_RegionSlice(entry.key, percent, palette[i % palette.length]));
    }

    final topOrders = [...orders]..sort((a, b) => b.amount.compareTo(a.amount));

    return _ReportsData(
      orders: orders,
      dailySales: dailySales,
      dailyLabels: dailyLabels,
      salesThisMonth: salesThisMonth,
      monthDeltaLabel: monthDeltaLabel,
      topProductName: topProductName,
      topProductUnits: topProductUnits,
      rejectedOrders: rejectedOrders,
      rejectedRate: orders.isEmpty ? 0 : rejectedRate,
      regionMix: regionMix,
      topOrders: topOrders.take(6).toList(),
    );
  }
}

Color _reportStatusColor(String status) {
  switch (status) {
    case 'Pending':
      return const Color(0xFFFFB547);
    case 'Approved':
      return const Color(0xFF22C55E);
    case 'Ready to Dispatch':
      return const Color(0xFF0EA5E9);
    case 'In Transit':
      return const Color(0xFF6C7AFF);
    case 'Delivered':
      return const Color(0xFF22C55E);
    case 'Rejected':
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}

double _asNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _rupee(double value) {
  final rounded = value.round().toString();
  final chars = rounded.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) out.add(',');
    out.add(chars[i]);
  }
  return '₹ ${out.reversed.join()}';
}

String _compactNumber(double value) {
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

// ---------- PDF export ----------

pw.Document _buildReportPdf(_ReportsData data) {
  final navy = PdfColor.fromHex('#12377D');
  final blue = PdfColor.fromHex('#1665D8');
  final border = PdfColor.fromHex('#D6E2F5');
  final muted = PdfColor.fromHex('#63708A');
  final paleBlue = PdfColor.fromHex('#F2F7FF');
  final generatedOn = DateTime.now();

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(26, 24, 26, 24),
      build: (context) => [
        pw.Row(
          children: [
            pw.Container(
              width: 42,
              height: 42,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(color: blue, borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Text('S', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Sales Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: navy)),
                  pw.Text(
                    'Generated on ${_pdfDate(generatedOn)}',
                    style: pw.TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _pdfMetricBox('Total Orders', '${data.orders.length}', navy, border),
            pw.SizedBox(width: 8),
            _pdfMetricBox('Sales This Month', _rupee(data.salesThisMonth), navy, border),
            pw.SizedBox(width: 8),
            _pdfMetricBox('Top Product', data.topProductName, navy, border),
            pw.SizedBox(width: 8),
            _pdfMetricBox('Rejected Orders', '${data.rejectedOrders}', navy, border),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Region Mix', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navy)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: border),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.4)},
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: paleBlue),
              children: [
                _pdfCell('Region', bold: true),
                _pdfCell('Share', bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...data.regionMix.map(
              (r) => pw.TableRow(
                children: [
                  _pdfCell(r.name),
                  _pdfCell('${r.percent.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Top Orders by Value', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navy)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: border),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FlexColumnWidth(1.6),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.3),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: paleBlue),
              children: [
                _pdfCell('Order ID', bold: true),
                _pdfCell('Shop', bold: true),
                _pdfCell('Salesman', bold: true),
                _pdfCell('Amount', bold: true, align: pw.TextAlign.right),
                _pdfCell('Status', bold: true),
              ],
            ),
            ...data.orders.map(
              (o) => pw.TableRow(
                children: [
                  _pdfCell(o.orderId),
                  _pdfCell(o.shop),
                  _pdfCell(o.salesman),
                  _pdfCell(_rupee(o.amount), align: pw.TextAlign.right),
                  _pdfCell(o.status),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc;
}

pw.Widget _pdfMetricBox(String label, String value, PdfColor navy, PdfColor border) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: border), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#63708A'))),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy), maxLines: 1),
        ],
      ),
    ),
  );
}

pw.Widget _pdfCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      maxLines: 2,
    ),
  );
}

String _pdfDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

// ---------- CSV export ----------

String _buildReportCsv(_ReportsData data) {
  final buffer = StringBuffer();

  buffer.writeln('Sales Report');
  buffer.writeln('Generated On,${_pdfDate(DateTime.now())}');
  buffer.writeln();

  buffer.writeln('Summary');
  buffer.writeln('Metric,Value');
  buffer.writeln('Total Orders,${data.orders.length}');
  buffer.writeln('Sales This Month,${data.salesThisMonth.toStringAsFixed(2)}');
  buffer.writeln('Top Product,${_csvEscape(data.topProductName)}');
  buffer.writeln('Rejected Orders,${data.rejectedOrders}');
  buffer.writeln();

  buffer.writeln('Region Mix');
  buffer.writeln('Region,Share (%)');
  for (final r in data.regionMix) {
    buffer.writeln('${_csvEscape(r.name)},${r.percent.toStringAsFixed(1)}');
  }
  buffer.writeln();

  buffer.writeln('Orders');
  buffer.writeln('Order ID,Shop,Salesman,Amount,Status');
  for (final o in data.orders) {
    buffer.writeln(
      '${_csvEscape(o.orderId)},${_csvEscape(o.shop)},${_csvEscape(o.salesman)},${o.amount.toStringAsFixed(2)},${_csvEscape(o.status)}',
    );
  }

  return buffer.toString();
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}