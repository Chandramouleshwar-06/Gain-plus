import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../reminders/reminder_planner.dart';
import 'settings_provider.dart';

const _kindInfo = {
  ReminderKind.workout: ('Scheduled workouts', 'At the time you picked when scheduling', Icons.alarm_rounded),
  ReminderKind.followUp: ('Follow-ups', "2 hours later if you haven't trained yet", Icons.update_rounded),
  ReminderKind.streak: ('Streak alerts', 'When your streak is about to end', Icons.local_fire_department_rounded),
  ReminderKind.weeklyGoal: ('Weekly target', 'Thursday and Saturday check-ins on your target', Icons.track_changes_rounded),
  ReminderKind.inactivity: ('Nudges', 'A gentle push after a few days off', Icons.waving_hand_rounded),
  ReminderKind.recap: ('Weekly recap', 'Your week in review, Sunday evening', Icons.insights_rounded),
};

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  String _hour(BuildContext context, int hour) => TimeOfDay(hour: hour, minute: 0).format(context);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('NOTIFICATIONS', style: AppText.display(36)),
          const SizedBox(height: 6),
          const Text('Reminders adapt to your schedule and training, and stop once you have trained.',
              style: AppText.muted),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final kind in ReminderKind.values)
                  SwitchListTile(
                    value: settings.reminderKinds[kind.name] ?? true,
                    onChanged: (v) => settings.setReminderKind(kind, v),
                    secondary: Icon(_kindInfo[kind]!.$3),
                    title: Text(_kindInfo[kind]!.$1, style: AppText.strong),
                    subtitle: Text(_kindInfo[kind]!.$2, style: AppText.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('LIMITS', style: AppText.eyebrow),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Quiet hours', style: AppText.strong),
                  subtitle: const Text('Only reminders you set a time for come through', style: AppText.muted),
                  trailing: Text(
                    '${_hour(context, settings.quietStartHour)} – ${_hour(context, settings.quietEndHour)}',
                    style: AppText.display(18, weight: FontWeight.w700, color: AppColors.lime),
                  ),
                  onTap: () => _pickQuietHours(context, settings),
                ),
                const Divider(indent: 16, endIndent: 16),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Most notifications per day', style: AppText.strong),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final cap in [1, 2, 3, 4])
                        ChoiceChip(
                          label: Text('$cap'),
                          selected: settings.dailyCap == cap,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: settings.dailyCap == cap ? AppColors.onLime : AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => settings.setDailyCap(cap),
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

  Future<void> _pickQuietHours(BuildContext context, SettingsProvider settings) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.quietStartHour, minute: 0),
      helpText: 'QUIET FROM',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.quietEndHour, minute: 0),
      helpText: 'QUIET UNTIL',
    );
    if (end == null) return;
    await settings.setQuietHours(start.hour, end.hour);
  }
}
