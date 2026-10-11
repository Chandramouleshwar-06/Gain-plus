import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

const _gridColor = Color(0xFF26262A);
const _axisLabel = TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600);

/// "12.4k" style compact number for axis labels.
String compactNumber(double value) => NumberFormat.compact().format(value);

/// Weekly volume bars, oldest week on the left. Touch a bar for its value.
class VolumeBarChart extends StatelessWidget {
  final List<(DateTime, double)> weeks;
  const VolumeBarChart({super.key, required this.weeks});

  @override
  Widget build(BuildContext context) {
    final peak = weeks.fold(0.0, (m, w) => w.$2 > m ? w.$2 : m);
    // Round axis steps (e.g. 250, 500, 1k) with room above the tallest bar.
    final interval = niceInterval(peak == 0 ? 1000 : peak / 3);
    final maxY = (peak / interval).floor() * interval + interval;
    return Semantics(
      label: 'Weekly volume for the last ${weeks.length} weeks. '
          'This week: ${weeks.isEmpty ? 0 : weeks.last.$2.toStringAsFixed(0)} kg.',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) => const FlLine(color: _gridColor, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: interval,
                  getTitlesWidget: (value, meta) => value == meta.max
                      ? const SizedBox.shrink()
                      : Text(compactNumber(value), style: _axisLabel),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                    final isLast = i == weeks.length - 1;
                    // Label every other week, plus this week.
                    if (!isLast && (weeks.length - 1 - i) % 2 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(isLast ? 'This wk' : DateFormat('d MMM').format(weeks[i].$1), style: _axisLabel),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipColor: (_) => AppColors.surfaceHigh,
                tooltipBorderRadius: BorderRadius.circular(10),
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  'Week of ${DateFormat('d MMM').format(weeks[group.x].$1)}\n',
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  children: [
                    TextSpan(
                      text: '${NumberFormat.decimalPattern().format(rod.toY.round())} kg',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < weeks.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: weeks[i].$2,
                      width: 18,
                      color: i == weeks.length - 1 ? AppColors.lime : AppColors.lime.withValues(alpha: 0.55),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      // Faint full-height track so empty weeks still read as weeks.
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: const Color(0xFF1C1C1F)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A value over time (e.g. estimated 1RM or body weight). Touch a point
/// for its date and value.
class TrendLineChart extends StatelessWidget {
  final List<(DateTime, double)> points;
  final String unit;
  final String semanticsLabel;

  const TrendLineChart({super.key, required this.points, required this.semanticsLabel, this.unit = 'kg'});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final values = points.map((p) => p.$2);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) == 0 ? (maxV == 0 ? 1 : maxV * 0.1) : (maxV - minV) * 0.2;
    final minY = (minV - pad).clamp(0, double.infinity).toDouble();
    final maxY = maxV + pad;
    final first = points.first.$1;
    double x(DateTime d) => d.difference(first).inHours / 24;
    final lastX = x(points.last.$1);

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: 0,
            maxX: lastX == 0 ? 1 : lastX,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
              getDrawingHorizontalLine: (_) => const FlLine(color: _gridColor, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: (maxY - minY) / 3,
                  getTitlesWidget: (value, meta) => value == meta.max || value == meta.min
                      ? const SizedBox.shrink()
                      : Text(formatWeight(double.parse(value.toStringAsFixed(1))), style: _axisLabel),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: lastX == 0 ? 1 : lastX,
                  getTitlesWidget: (value, meta) {
                    final date = first.add(Duration(hours: (value * 24).round()));
                    final align = value == meta.min ? Alignment.centerLeft : Alignment.centerRight;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(alignment: align, child: Text(DateFormat('d MMM').format(date), style: _axisLabel)),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (bar, indexes) => [
                for (final _ in indexes)
                  const TouchedSpotIndicatorData(
                    FlLine(color: AppColors.textMuted, strokeWidth: 1, dashArray: [4, 4]),
                    FlDotData(show: true),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipColor: (_) => AppColors.surfaceHigh,
                tooltipBorderRadius: BorderRadius.circular(10),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${DateFormat('d MMM y').format(points[s.spotIndex].$1)}\n',
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      children: [
                        TextSpan(
                          text: '${formatWeight(double.parse(s.y.toStringAsFixed(1)))} $unit',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final p in points) FlSpot(x(p.$1), p.$2)],
                color: AppColors.lime,
                barWidth: 2,
                isCurved: false,
                dotData: FlDotData(
                  show: points.length <= 30,
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.lime,
                    strokeWidth: 2,
                    strokeColor: AppColors.surface,
                  ),
                ),
                belowBarData: BarAreaData(show: true, color: AppColors.lime.withValues(alpha: 0.08)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round axis step at or above [rough]: 1, 2, 2.5 or 5 times a power of 10.
double niceInterval(double rough) {
  if (rough <= 0) return 1;
  final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
  for (final step in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (step * magnitude >= rough) return step * magnitude;
  }
  return 10 * magnitude;
}
