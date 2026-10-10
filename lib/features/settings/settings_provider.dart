import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../reminders/reminder_planner.dart';

/// Per-device preferences (not synced): rest timer and notifications.
class SettingsProvider extends ChangeNotifier {
  static const _restEnabledKey = 'rest_timer_enabled';
  static const _restSecondsKey = 'rest_timer_seconds';

  static const restOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  SharedPreferences? _prefs;

  bool restTimerEnabled = true;
  int restSeconds = 90;

  /// Which reminder kinds are on, by [ReminderKind.name].
  Map<String, bool> reminderKinds = {for (final k in ReminderKind.values) k.name: true};
  int quietStartHour = 22;
  int quietEndHour = 7;
  int dailyCap = 2;

  ReminderPrefs get reminderPrefs => ReminderPrefs(
        workout: reminderKinds[ReminderKind.workout.name]!,
        followUp: reminderKinds[ReminderKind.followUp.name]!,
        streak: reminderKinds[ReminderKind.streak.name]!,
        weeklyGoal: reminderKinds[ReminderKind.weeklyGoal.name]!,
        inactivity: reminderKinds[ReminderKind.inactivity.name]!,
        recap: reminderKinds[ReminderKind.recap.name]!,
        quietStartHour: quietStartHour,
        quietEndHour: quietEndHour,
        dailyCap: dailyCap,
      );

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    restTimerEnabled = _prefs!.getBool(_restEnabledKey) ?? true;
    restSeconds = _prefs!.getInt(_restSecondsKey) ?? 90;
    for (final k in ReminderKind.values) {
      reminderKinds[k.name] = _prefs!.getBool('reminder_${k.name}') ?? true;
    }
    quietStartHour = _prefs!.getInt('quiet_start') ?? 22;
    quietEndHour = _prefs!.getInt('quiet_end') ?? 7;
    dailyCap = _prefs!.getInt('daily_cap') ?? 2;
    notifyListeners();
  }

  /// Rest length to start after a completed set, or null when the timer is off.
  int? get restAfterSet => restTimerEnabled ? restSeconds : null;

  Future<void> setRestTimerEnabled(bool value) async {
    restTimerEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_restEnabledKey, value);
  }

  Future<void> setReminderKind(ReminderKind kind, bool enabled) async {
    reminderKinds = {...reminderKinds, kind.name: enabled};
    notifyListeners();
    await _prefs?.setBool('reminder_${kind.name}', enabled);
  }

  Future<void> setQuietHours(int startHour, int endHour) async {
    quietStartHour = startHour;
    quietEndHour = endHour;
    notifyListeners();
    await _prefs?.setInt('quiet_start', startHour);
    await _prefs?.setInt('quiet_end', endHour);
  }

  Future<void> setDailyCap(int value) async {
    dailyCap = value;
    notifyListeners();
    await _prefs?.setInt('daily_cap', value);
  }

  Future<void> setRestSeconds(int value) async {
    restSeconds = value;
    notifyListeners();
    await _prefs?.setInt(_restSecondsKey, value);
  }
}

/// "1:30", "45s", "2 min".
String formatRest(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m:${s.toString().padLeft(2, '0')}';
}
