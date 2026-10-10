import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../exercise/exercise_provider.dart';
import '../progress/progress_provider.dart';
import 'profile_provider.dart';

/// Human-readable goal title, e.g. "Bench Press (Barbell) 100 kg".
String goalTitle(Goal goal, ExerciseProvider exercises) {
  final target = '${formatWeight(goal.targetValue)} kg';
  return switch (goal.type) {
    Goal.typeLift => '${exercises.byId(goal.exerciseId ?? '')?.name ?? 'Lift'} $target',
    Goal.typeBodyWeight => 'Reach $target body weight',
    _ => target,
  };
}

/// A goal with its progress bar.
class GoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onLongPress;

  const GoalTile({super.key, required this.goal, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final prs = context.watch<ProgressProvider>().prKgByExerciseId;
    final exercises = context.watch<ExerciseProvider>();

    final current = profile.currentValue(goal, prs);
    final progress = current == null ? 0.0 : ProfileProvider.goalProgress(goal, current);
    final achieved = goal.achievedAt != null || progress >= 1;

    final status = achieved
        ? 'Done!'
        : current == null
            ? (goal.type == Goal.typeLift ? 'No sets yet' : 'Log your weight')
            : '${formatWeight(current)} kg';

    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (achieved) ...[
                  const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: 18),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(goalTitle(goal, exercises), style: AppText.strong)),
                const SizedBox(width: 8),
                Text(status, style: AppText.muted),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(value: achieved ? 1 : progress, color: achieved ? AppColors.orange : AppColors.lime),
            if (goal.deadline != null && !achieved) ...[
              const SizedBox(height: 6),
              Text('By ${DateFormat('d MMM y').format(goal.deadline!)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
