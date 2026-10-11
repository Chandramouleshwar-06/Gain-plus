import 'package:flutter/material.dart';
import '../../data/muscles.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'muscle_analysis.dart';

/// Hard sets per muscle group over the last 7 days, against the usual
/// 10-20 set target (shaded).
class MuscleBalanceChart extends StatelessWidget {
  final Map<String, double> setsByGroup;
  const MuscleBalanceChart({super.key, required this.setsByGroup});

  @override
  Widget build(BuildContext context) {
    final (low, high) = recommendedWeeklySets;
    final peak = setsByGroup.values.fold(high + 4, (m, v) => v > m ? v : m);

    return Semantics(
      label: 'Hard sets per muscle group in the last 7 days. '
          '${Muscle.groups.map((g) => '$g ${formatWeight(setsByGroup[g] ?? 0)}').join(', ')}. '
          'Target ${low.round()} to ${high.round()}.',
      excludeSemantics: true,
      child: Column(
        children: [
          for (final group in Muscle.groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _Row(group: group, sets: setsByGroup[group] ?? 0, peak: peak),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 14,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text('Target: ${low.round()}–${high.round()} hard sets a week',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String group;
  final double sets;
  final double peak;

  const _Row({required this.group, required this.sets, required this.peak});

  @override
  Widget build(BuildContext context) {
    final (low, high) = recommendedWeeklySets;
    final (status, color) = sets < low
        ? ('low', AppColors.lime.withValues(alpha: 0.45))
        : sets <= high
            ? ('on target', AppColors.lime)
            : ('high', AppColors.orange);

    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group, style: AppText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(status, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            double x(double v) => (v / peak).clamp(0.0, 1.0) * w;
            return SizedBox(
              height: 18,
              child: Stack(
                children: [
                  // Target range band.
                  Positioned(
                    left: x(low),
                    width: x(high) - x(low),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    width: sets == 0 ? 0 : x(sets).clamp(4.0, w),
                    top: 4,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(formatWeight(sets), textAlign: TextAlign.right, style: AppText.strong),
        ),
      ],
    );
  }
}
