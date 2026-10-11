import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/activity_types.dart';
import '../../models/activity.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ui.dart';
import '../nutrition/nutrition_provider.dart';
import 'activity_provider.dart';
import 'log_activity_screen.dart';

/// Runs, swims, sports and everything else that isn't a gym workout.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityProvider>();
    final byDay = <DateTime, List<Activity>>{};
    for (final a in provider.recent) {
      byDay.putIfAbsent(DateTime(a.startedAt.year, a.startedAt.month, a.startedAt.day), () => []).add(a);
    }

    return Scaffold(
      appBar: AppBar(title: Text('ACTIVITIES', style: AppText.display(22))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openLogActivity(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        children: [
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: AppColors.orange, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BURNED TODAY', style: AppText.eyebrow),
                      Text('${provider.burnedToday.round()} kcal', style: AppText.display(30)),
                      const Text('Activities and gym workouts', style: AppText.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (provider.recent.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.directions_run_rounded,
                title: 'No activities yet',
                message: 'Log a run, swim, ride or game and see the calories you burned.',
              ),
            ),
          for (final entry in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(_dayLabel(entry.key).toUpperCase(), style: AppText.eyebrow),
            ),
            for (final a in entry.value) ...[
              ActivityTile(activity: a),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday';
    return DateFormat('EEE d MMM').format(day);
  }
}

Future<void> openLogActivity(BuildContext context, {Activity? existing}) async {
  final saved = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => LogActivityScreen(existing: existing)));
  if (saved == true && context.mounted) {
    await context.read<NutritionProvider>().load();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity saved.')));
  }
}

/// One activity; tap to edit, swipe to delete.
class ActivityTile extends StatelessWidget {
  final Activity activity;
  const ActivityTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final type = activityType(activity.type);
    final details = [
      formatDuration(activity.durationSeconds),
      if (activity.distanceMeters != null) '${(activity.distanceMeters! / 1000).toStringAsFixed(2)} km',
      DateFormat('h:mm a').format(activity.startedAt),
      if (activity.source == 'health') 'from Health',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Delete activity?',
        message: 'This ${type.label.toLowerCase()} will be removed.',
        confirmLabel: 'Delete',
        destructive: true,
      ),
      onDismissed: (_) async {
        await context.read<ActivityProvider>().delete(activity.id);
        if (context.mounted) await context.read<NutritionProvider>().load();
      },
      child: AppCard(
        onTap: () => openLogActivity(context, existing: activity),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(type.icon, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: AppText.strong),
                  const SizedBox(height: 2),
                  Text(details, style: AppText.muted, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${activity.kcal.round()} kcal', style: AppText.strong),
          ],
        ),
      ),
    );
  }
}
