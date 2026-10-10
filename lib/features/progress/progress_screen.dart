import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ui.dart';
import '../home/home_screen.dart';
import 'progress_provider.dart';
import '../../widgets/charts.dart';
import 'exercise_progress_screen.dart';
import 'workout_detail_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.lime,
          onRefresh: provider.loadData,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const ScreenHeader(title: 'Progress'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppColors.orange,
                            value: '${provider.streak}',
                            label: 'day streak',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            icon: Icons.fitness_center_rounded,
                            value: '${provider.totalWorkouts}',
                            label: 'workouts',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            icon: Icons.trending_up_rounded,
                            value: '${(provider.totalVolume / 1000).toStringAsFixed(1)}t',
                            label: 'total volume',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Weekly volume'),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: VolumeBarChart(weeks: provider.weeklyVolume),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Lifts'),
                    if (provider.lifts.isEmpty)
                      const AppCard(child: Text('Finish a workout to see your lifts and PRs.', style: AppText.muted))
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < provider.lifts.length; i++) ...[
                              if (i > 0) const Divider(indent: 16, endIndent: 16),
                              _LiftRow(lift: provider.lifts[i]),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'History'),
                    if (provider.recentWorkouts.isEmpty)
                      const AppCard(child: Text('No workouts yet.', style: AppText.muted))
                    else
                      for (final w in provider.recentWorkouts) ...[
                        WorkoutSummaryCard(
                          workout: w,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutId: w.id)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiftRow extends StatelessWidget {
  final LiftSummary lift;
  const _LiftRow({required this.lift});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExerciseProgressScreen(exerciseId: lift.exerciseId, name: lift.name),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lift.name, style: AppText.strong),
                  Text('Est. 1RM ${formatWeight(lift.bestE1rm.roundToDouble())} kg', style: AppText.muted),
                ],
              ),
            ),
            Text('${formatWeight(lift.prWeight)} × ${lift.prReps}', style: AppText.display(20, weight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
