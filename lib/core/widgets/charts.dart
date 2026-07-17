import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'premium_widgets.dart';

class ChartSlice {
  const ChartSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.color,
    this.labels = const [],
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final Color color;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _LineChartPainter(values: values, color: color),
              child: Container(),
            ),
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels
                  .map(
                    (label) => Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class DonutChartCard extends StatelessWidget {
  const DonutChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<ChartSlice> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _DonutChartPainter(items: items),
                    child: Container(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Text(
                                '${item.value.toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class BarChartCard extends StatelessWidget {
  const BarChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _BarChartPainter(values: values, color: color),
              child: Container(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map(
                  (label) => Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final backgroundPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final dy = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), backgroundPaint);
    }

    final path = Path();
    final fillPath = Path();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    for (var i = 0; i < values.length; i++) {
      final x = i * (size.width / (values.length - 1));
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height * 0.78)) - 10;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.26), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final x = i * (size.width / (values.length - 1));
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height * 0.78)) - 10;
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.items});

  final List<ChartSlice> items;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) return;

    final rectSize = math.min(size.width, size.height) * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectSize,
      height: rectSize,
    );
    const startAngle = -math.pi / 2;
    final strokeWidth = rectSize * 0.22;
    var currentAngle = startAngle;

    for (final item in items) {
      final sweep = (item.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += sweep;
    }

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      rectSize * 0.32,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => oldDelegate.items != items;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final barWidth = size.width / (values.length * 1.7);
    final gap = barWidth * 0.7;
    final baseline = size.height - 16;
    for (var i = 0; i < values.length; i++) {
      final height = (values[i] / maxValue) * (size.height * 0.72);
      final left = i * (barWidth + gap) + (gap * 0.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - height, barWidth, height),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.95), color.withOpacity(0.45)],
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}