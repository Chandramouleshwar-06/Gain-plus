import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/activity_repository.dart';
import '../../data/activity_types.dart';
import '../../data/profile_repository.dart';
import '../../data/sync_columns.dart';
import '../../models/activity.dart';
import '../../models/workout.dart';
import '../../services/health_service.dart';
import '../../utils/date_keys.dart';
import 'health_import.dart';

/// Health Connect (Android) / Apple Health: opt-in, then today's steps,
/// calories, heart rate and sleep, plus imported workouts and weight.
class HealthProvider extends ChangeNotifier {
  final HealthService _service;
  HealthProvider([HealthService? service]) : _service = service ?? PluginHealthService() {
    ready = init();
  }

  /// Completes once the saved setting and Health Connect status are known.
  late final Future<void> ready;

  static const _enabledKey = 'health_enabled';

  HealthStatus status = HealthStatus.unsupported;
  bool enabled = false;
  bool busy = false;
  HealthDaySummary? today;

  /// Steps for the last 7 days, oldest first.
  List<(DateTime, int)> weekSteps = [];
  DateTime? lastSynced;
  String? error;

  bool get connected => enabled && status == HealthStatus.available;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? false;
      status = await _service.status();
    } catch (e) {
      debugPrint('Health unavailable: $e');
      status = HealthStatus.unsupported;
    }
    notifyListeners();
  }

  Future<void> _setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Asks for access. Returns true when connected.
  Future<bool> connect() async {
    status = await _service.status();
    if (status == HealthStatus.notInstalled || status == HealthStatus.needsUpdate) {
      await _service.install();
      notifyListeners();
      return false;
    }
    if (status != HealthStatus.available) return false;
    final granted = await _service.requestPermissions();
    await _setEnabled(granted);
    error = granted ? null : 'Access was not given. You can allow it in Health Connect.';
    notifyListeners();
    return granted;
  }

  Future<void> disconnect() async {
    await _setEnabled(false);
    today = null;
    weekSteps = [];
    notifyListeners();
    try {
      await _service.revokePermissions();
    } catch (e) {
      debugPrint('Could not revoke health access: $e');
    }
  }

  /// Reads today's numbers and imports new workouts and weight. Returns
  /// how many activities were imported.
  Future<int> refresh({required BodyMetrics body}) async {
    if (!connected || busy) return 0;
    busy = true;
    notifyListeners();
    var imported = 0;
    try {
      if (!await _service.hasPermissions()) {
        error = 'Gain+ no longer has access. Connect again to allow it.';
        await _setEnabled(false);
        return 0;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      today = await _service.day(now);
      weekSteps = [
        for (var i = 6; i >= 0; i--)
          (start.subtract(Duration(days: i)),
              await _service.steps(start.subtract(Duration(days: i)), start.subtract(Duration(days: i - 1))) ?? 0),
      ];
      imported = await importWorkouts(since: start.subtract(const Duration(days: 30)), body: body);
      await importWeight(since: start.subtract(const Duration(days: 30)));
      lastSynced = DateTime.now();
      error = null;
    } catch (e) {
      debugPrint('Health refresh failed: $e');
      error = "Couldn't read from Health Connect.";
    } finally {
      busy = false;
      notifyListeners();
    }
    return imported;
  }

  /// Adds health workouts not seen before as activities.
  Future<int> importWorkouts({required DateTime since, required BodyMetrics body}) async {
    final repo = ActivityRepository.instance;
    final records = await _service.workouts(since, DateTime.now());
    final activities = activitiesFromHealth(
      records,
      alreadyImported: await repo.importedExternalIds(),
      body: body,
      newId: newId,
    );
    for (final a in activities) {
      await repo.save(a);
    }
    return activities.length;
  }

  /// Adds the newest health weigh-in if there's no weight logged that day.
  Future<bool> importWeight({required DateTime since}) async {
    final latest = await _service.latestWeight(since);
    if (latest == null) return false;
    final (date, kg) = latest;
    final repo = ProfileRepository.instance;
    final existing = await repo.getBodyWeights();
    if (existing.any((w) => dateKey(w.date) == dateKey(date))) return false;
    await repo.addBodyWeight(date, kg, source: 'health');
    return true;
  }

  /// Writes a logged activity to the health store (best effort).
  Future<void> exportActivity(Activity a) async {
    if (!connected || a.source == 'health') return;
    try {
      await _service.writeWorkout(
        type: healthTypeForActivity(a.type),
        start: a.startedAt,
        end: a.startedAt.add(a.duration),
        kcal: a.kcal,
        distanceMeters: a.distanceMeters,
        title: activityType(a.type).label,
      );
    } catch (e) {
      debugPrint('Could not write activity to health: $e');
    }
  }

  /// Writes a gym workout to the health store (best effort).
  Future<void> exportWorkout(Workout w) async {
    if (!connected) return;
    try {
      await _service.writeWorkout(
        type: healthTypeForActivity('strength'),
        start: w.startedAt,
        end: w.startedAt.add(Duration(seconds: w.durationSeconds)),
        kcal: w.kcal,
        title: w.name,
      );
    } catch (e) {
      debugPrint('Could not write workout to health: $e');
    }
  }
}
