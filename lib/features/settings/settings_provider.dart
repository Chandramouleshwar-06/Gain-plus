import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device preferences (not synced): rest timer and notifications.
class SettingsProvider extends ChangeNotifier {
  static const _restEnabledKey = 'rest_timer_enabled';
  static const _restSecondsKey = 'rest_timer_seconds';

  static const restOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  SharedPreferences? _prefs;

  bool restTimerEnabled = true;
  int restSeconds = 90;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    restTimerEnabled = _prefs!.getBool(_restEnabledKey) ?? true;
    restSeconds = _prefs!.getInt(_restSecondsKey) ?? 90;
    notifyListeners();
  }

  /// Rest length to start after a completed set, or null when the timer is off.
  int? get restAfterSet => restTimerEnabled ? restSeconds : null;

  Future<void> setRestTimerEnabled(bool value) async {
    restTimerEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_restEnabledKey, value);
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
