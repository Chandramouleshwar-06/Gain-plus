import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/workout_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/strength.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

enum _Metric { e1rm, topWeight, volume }

/// One exercise over time: estimated 1RM, heaviest set or volume.
class ExerciseProgressScreen extends StatefulWidget {
  final String exerciseId;
  final String name;

  const ExerciseProgressScreen({super.key, required this.exerciseId, required this.name});

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  late final Future<List<ExerciseSession>> _history =
      WorkoutRepository.instance.getExerciseHistory(widget.exerciseId);
  _Metric _metric = _Metric.e1rm;

  static double _bestE1rm(ExerciseSession s) =>
      s.sets.fold(0.0, (m, set) => estimateOneRepMax(set.weight, set.reps) > m ? estimateOneRepMax(set.weight, set.reps) : m);
  static double _topWeight(ExerciseSession s) => s.sets.fold(0.0, (m, set) => set.weight > m ? set.weight : m);
  static double _volume(ExerciseSession s) => s.sets.fold(0.0, (sum, set) => sum + set.weight * set.reps);

  double _value(ExerciseSession s) => switch (_metric) {
        _Metric.e1rm => _bestE1rm(s),
        _Metric.topWeight => _topWeight(s),
        _Metric.volume => _volume(s),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<ExerciseSession>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.lime));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const EmptyState(icon: Icons.show_chart_rounded, title: 'No data yet', message: 'Log this exercise to see your progress.');
          }

          final bestE1rm = sessions.map(_bestE1rm).reduce((a, b) => a > b ? a : b);
          final topWeight = sessions.map(_topWeight).reduce((a, b) => a > b ? a : b);
          final points = [for (final s in sessions) (s.date, double.parse(_value(s).toStringAsFixed(1)))];
          final metricLabel = switch (_metric) {
            _Metric.e1rm => 'estimated one-rep max',
            _Metric.topWeight => 'heaviest set',
            _Metric.volume => 'volume per session',
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(widget.name.toUpperCase(), style: AppText.display(32)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: StatTile(icon: Icons.bolt_rounded, value: formatWeight(bestE1rm.roundToDouble()), label: 'best est. 1RM (kg)')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.orange,
                      value: formatWeight(topWeight),
                      label: 'heaviest (kg)',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(icon: Icons.event_repeat_rounded, value: '${sessions.length}', label: 'sessions')),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (metric, label) in [
                            (_Metric.e1rm, 'Est. 1RM'),
                            (_Metric.topWeight, 'Heaviest'),
                            (_Metric.volume, 'Volume'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _metric == metric,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: _metric == metric ? AppColors.onLime : AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) => setState(() => _metric = metric),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (points.length < 2)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Do this exercise one more time to see a trend.', style: AppText.muted),
                      )
                    else
                      TrendLineChart(
                        points: points,
                        semanticsLabel: '${widget.name} $metricLabel over ${points.length} sessions, '
                            'from ${formatWeight(points.first.$2)} to ${formatWeight(points.last.$2)} kg.',
                      ),
                  ],
                ),
              ),
              if (_metric == _Metric.e1rm)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text('Estimated 1RM = the most you could likely lift once, worked out from your sets (Epley formula).',
                      style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
                ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Sessions'),
              for (final s in sessions.reversed) ...[
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(DateFormat('d MMM y').format(s.date), style: AppText.muted),
                      ),
                      Expanded(
                        child: Text(
                          s.sets.map((set) => '${formatWeight(set.weight)}×${set.reps}').join('   '),
                          style: AppText.strong,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
