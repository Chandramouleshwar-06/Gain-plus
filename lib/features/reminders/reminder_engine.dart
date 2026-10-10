import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import 'reminder_planner.dart';

/// Turns the reminder plan into scheduled notifications, replacing
/// whatever was scheduled before.
class ReminderEngine {
  static final ReminderEngine instance = ReminderEngine._();
  ReminderEngine._();

  static const _idsKey = 'scheduled_reminder_ids';
  static const _legacyClearedKey = 'legacy_reminders_cleared';

  Future<void> _running = Future.value();

  /// Re-plans all reminders. Calls are queued so two re-plans never overlap.
  Future<void> replan(ReminderInput input, {List<DateTime> legacyScheduleDates = const []}) {
    return _running = _running.then((_) => _replan(input, legacyScheduleDates)).catchError((Object e) {
      debugPrint('Reminder re-plan failed: $e');
    });
  }

  Future<void> _replan(ReminderInput input, List<DateTime> legacyScheduleDates) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = NotificationService.instance;

    // Older versions scheduled workout reminders with yyyymmdd IDs.
    if (!(prefs.getBool(_legacyClearedKey) ?? false)) {
      for (final date in legacyScheduleDates) {
        await notifications.cancelReminder(date.year * 10000 + date.month * 100 + date.day);
      }
      await prefs.setBool(_legacyClearedKey, true);
    }

    final previous = prefs.getStringList(_idsKey)?.map(int.parse).toSet() ?? <int>{};
    final planned = planReminders(input);
    final plannedIds = planned.map((r) => r.id).toSet();

    for (final id in previous.difference(plannedIds)) {
      await notifications.cancelReminder(id);
    }
    for (final r in planned) {
      await notifications.scheduleReminder(r.id, r.title, r.body, r.at, channel: _channelFor(r.kind));
    }
    await prefs.setStringList(_idsKey, plannedIds.map((id) => '$id').toList());
  }

  ReminderChannel _channelFor(ReminderKind kind) => switch (kind) {
        ReminderKind.workout || ReminderKind.followUp => ReminderChannel.workouts,
        ReminderKind.recap => ReminderChannel.recap,
        _ => ReminderChannel.motivation,
      };
}
