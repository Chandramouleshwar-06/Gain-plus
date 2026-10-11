import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ui.dart';
import '../profile/profile_provider.dart';
import 'progress_provider.dart';

/// One past workout with every exercise and set.
class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  // Loaded once, not on every rebuild (e.g. when the profile reloads).
  late final Future<Workout?> _workout = WorkoutRepository.instance.getWithDetails(widget.workoutId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Delete workout',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: FutureBuilder<Workout?>(
        future: _workout,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.lime));
          }
          final workout = snapshot.data;
          if (workout == null) {
            return const EmptyState(icon: Icons.history_rounded, title: 'Not found', message: 'This workout was deleted.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(DateFormat('EEEE d MMMM y · HH:mm').format(workout.startedAt).toUpperCase(), style: AppText.eyebrow),
              const SizedBox(height: 4),
              Text(workout.name.toUpperCase(), style: AppText.display(34)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: StatTile(icon: Icons.timer_outlined, value: formatDuration(workout.durationSeconds), label: 'duration')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.layers_outlined,
                      value: '${workout.exercises.fold(0, (s, e) => s + e.sets.length)}',
                      label: 'sets',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.trending_up_rounded,
                      value: context.watch<ProfileProvider>().units.volume(workout.totalVolume),
                      label: 'volume',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final entry in workout.exercises) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.exerciseName.toUpperCase(), style: AppText.display(22, weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (final set in entry.sets)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  switch (set.setType) {
                                    SetType.warmup => 'W',
                                    SetType.drop => 'D',
                                    SetType.failure => 'F',
                                    _ => '${set.position + 1}',
                                  },
                                  style: AppText.muted,
                                ),
                              ),
                              Text('${context.watch<ProfileProvider>().units.weight(set.weight)} × ${set.reps}', style: AppText.strong),
                              if (set.rpe != null) ...[
                                const SizedBox(width: 8),
                                Text('@${formatWeight(set.rpe!)}', style: AppText.muted),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete workout?',
      message: 'This removes it from your history, stats and PRs.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final progress = context.read<ProgressProvider>();
    await WorkoutRepository.instance.delete(widget.workoutId);
    await progress.loadData();
    navigator.pop();
  }
}
