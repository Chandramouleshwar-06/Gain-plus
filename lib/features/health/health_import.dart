import 'dart:math';
import '../../data/activity_types.dart';
import '../../models/activity.dart';
import '../../services/health_service.dart';

/// This app's package, so workouts it wrote aren't imported back.
const ownHealthSource = 'com.tracker1.gainplus';

/// Health workout types for each activity; the first is used when writing.
const _healthTypes = <String, List<String>>{
  'running': ['RUNNING', 'RUNNING_TREADMILL'],
  'walking': ['WALKING', 'WALKING_TREADMILL'],
  'cycling': ['BIKING', 'BIKING_STATIONARY'],
  'swimming': ['SWIMMING_POOL', 'SWIMMING', 'SWIMMING_OPEN_WATER'],
  'hiking': ['HIKING'],
  'hiit': ['HIGH_INTENSITY_INTERVAL_TRAINING'],
  'yoga': ['YOGA', 'PILATES'],
  'rowing': ['ROWING', 'ROWING_MACHINE'],
  'skipping': ['OTHER', 'JUMP_ROPE'],
  'elliptical': ['ELLIPTICAL'],
  'stairs': ['STAIR_CLIMBING', 'STAIR_CLIMBING_MACHINE', 'STAIRS'],
  'football': ['OTHER', 'SOCCER'],
  'cricket': ['CRICKET'],
  'badminton': ['BADMINTON'],
  'basketball': ['BASKETBALL'],
  'tennis': ['TENNIS', 'TABLE_TENNIS'],
  'dancing': ['DANCING', 'CARDIO_DANCE', 'SOCIAL_DANCE'],
  'strength': [
    'STRENGTH_TRAINING',
    'TRADITIONAL_STRENGTH_TRAINING',
    'FUNCTIONAL_STRENGTH_TRAINING',
    'WEIGHTLIFTING',
    'CALISTHENICS',
  ],
};

/// The activity code for a health workout type.
String activityCodeForHealth(String healthType) {
  for (final MapEntry(:key, :value) in _healthTypes.entries) {
    // 'OTHER' is only a write fallback for types Health Connect lacks.
    if (healthType != 'OTHER' && value.contains(healthType)) return key;
  }
  return 'other';
}

/// The health workout type to write for an activity code.
String healthTypeForActivity(String code) => _healthTypes[code]?.first ?? 'OTHER';

/// Health workouts as activities, skipping ones this app wrote and ones
/// already imported. Calories come from the record (e.g. a watch) when it
/// has them, otherwise they're estimated. Record calories are capped at
/// twice the estimate: the plugin adds up every calorie record in the
/// session's time, which can include resting burn or duplicates.
List<Activity> activitiesFromHealth(
  List<HealthWorkoutRecord> records, {
  required Set<String> alreadyImported,
  required BodyMetrics body,
  required String Function(HealthWorkoutRecord record) idFor,
}) {
  final result = <Activity>[];
  for (final r in records) {
    if (r.source == ownHealthSource || alreadyImported.contains(r.id)) continue;
    final duration = r.end.difference(r.start);
    if (duration.inMinutes < 1) continue;
    final type = activityType(activityCodeForHealth(r.type));
    final distanceKm = r.distanceMeters == null ? null : r.distanceMeters! / 1000;
    final estimate =
        estimateKcal(met: metFor(type, duration: duration, distanceKm: distanceKm), body: body, duration: duration);
    result.add(Activity(
      id: idFor(r),
      type: type.code,
      startedAt: r.start,
      durationSeconds: duration.inSeconds,
      distanceMeters: type.hasDistance ? r.distanceMeters : null,
      kcal: r.kcal != null && r.kcal! > 0 ? min(r.kcal!, estimate * 2).roundToDouble() : estimate,
      source: 'health',
      externalId: r.id,
    ));
  }
  return result;
}
