import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ui.dart';
import '../home/home_screen.dart';
import '../profile/profile_provider.dart';
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
                            value: formatVolume(provider.totalVolume),
                            label: 'lifted',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _ThisWeekCard(),
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
                  Text(
                    lift.isBodyweight ? 'Bodyweight' : 'Est. 1RM ${formatWeight(lift.bestE1rm.roundToDouble())} kg',
                    style: AppText.muted,
                  ),
                ],
              ),
            ),
            Text(
              lift.isBodyweight ? '${lift.prReps} reps' : '${formatWeight(lift.prWeight)} kg × ${lift.prReps}',
              style: AppText.display(20, weight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// This week so far vs the target and last week, with new PRs.
class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard();

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final target = context.watch<ProfileProvider>().weeklyTarget;
    final week = progress.thisWeek;
    if (week == null) return const SizedBox.shrink();

    final change = week.volumeChange;
    final hit = week.workouts >= target;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hit ? AppColors.lime : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK', style: AppText.eyebrow.copyWith(color: hit ? AppColors.onLime : AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Both sides scale down rather than overflow with large text.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${week.workouts}/$target',
                          style: AppText.display(44, color: hit ? AppColors.onLime : AppColors.text)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(hit ? 'target hit!' : 'workouts',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: hit ? AppColors.onLime : AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatVolume(week.volume),
                      style: AppText.display(26, color: hit ? AppColors.onLime : AppColors.text)),
                  if (change != null)
                    Text(
                      '${change >= 0 ? '▲' : '▼'} ${(change.abs() * 100).round()}% vs last week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hit ? AppColors.onLime : (change >= 0 ? AppColors.lime : AppColors.textMuted),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (week.newPrs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in week.newPrs)
                  hit ? InfoChip.onLime('PR · $name') : InfoChip('PR · $name', foreground: AppColors.orange),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
