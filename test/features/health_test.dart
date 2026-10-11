import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/activity_repository.dart';
import 'package:gain_plus/data/activity_types.dart';
import 'package:gain_plus/data/profile_repository.dart';
import 'package:gain_plus/features/health/health_import.dart';
import 'package:gain_plus/features/health/health_provider.dart';
import 'package:gain_plus/models/activity.dart';
import 'package:gain_plus/models/workout.dart';
import 'package:gain_plus/services/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_db.dart';

class FakeHealth implements HealthService {
  HealthStatus currentStatus = HealthStatus.available;
  bool granted = true;
  bool installed = false;
  List<HealthWorkoutRecord> records = [];
  (DateTime, double)? weight;
  final written = <Map<String, Object?>>[];

  @override
  Future<HealthStatus> status() async => currentStatus;
  @override
  Future<void> install() async => installed = true;
  @override
  Future<bool> hasPermissions() async => granted;
  @override
  Future<bool> requestPermissions() async => granted;
  @override
  Future<void> revokePermissions() async => granted = false;
  @override
  Future<HealthDaySummary> day(DateTime day) async =>
      const HealthDaySummary(steps: 8000, activeKcal: 420, restingHeartRate: 58, sleep: Duration(hours: 7));
  @override
  Future<int?> steps(DateTime start, DateTime end) async => start.day * 100;
  @override
  Future<List<HealthWorkoutRecord>> workouts(DateTime start, DateTime end) async => records;
  @override
  Future<(DateTime, double)?> latestWeight(DateTime since) async => weight;
  @override
  Future<bool> writeWorkout({
    required String type,
    required DateTime start,
    required DateTime end,
    double? kcal,
    double? distanceMeters,
    String? title,
  }) async {
    written.add({'type': type, 'kcal': kcal, 'distance': distanceMeters, 'title': title});
    return true;
  }
}

void main() {
  group('mapping', () {
    test('health workout types map to activities and back', () {
      expect(activityCodeForHealth('RUNNING_TREADMILL'), 'running');
      expect(activityCodeForHealth('SWIMMING_OPEN_WATER'), 'swimming');
      expect(activityCodeForHealth('WEIGHTLIFTING'), 'strength');
      expect(activityCodeForHealth('GOLF'), 'other');
      expect(activityCodeForHealth('OTHER'), 'other', reason: 'not football or skipping');
      expect(healthTypeForActivity('cycling'), 'BIKING');
      expect(healthTypeForActivity('football'), 'OTHER', reason: 'Health Connect has no soccer type in the plugin');
    });

    test('imports skip own and seen records; use the record calories or estimate', () {
      final start = DateTime(2026, 10, 1, 7);
      final activities = activitiesFromHealth(
        [
          HealthWorkoutRecord(id: 'r1', type: 'RUNNING', start: start, end: start.add(const Duration(minutes: 30)),
              kcal: 312.4, distanceMeters: 5000, source: 'com.strava'),
          HealthWorkoutRecord(id: 'r2', type: 'YOGA', start: start, end: start.add(const Duration(hours: 1))),
          HealthWorkoutRecord(id: 'r3', type: 'BIKING', start: start, end: start.add(const Duration(hours: 1)),
              source: ownHealthSource),
          HealthWorkoutRecord(id: 'r4', type: 'WALKING', start: start, end: start.add(const Duration(hours: 1))),
          HealthWorkoutRecord(id: 'r5', type: 'WALKING', start: start, end: start.add(const Duration(seconds: 20))),
        ],
        alreadyImported: {'r4'},
        body: const BodyMetrics(weightKg: 60),
        idFor: (r) => 'id-${r.id}',
      );
      expect(activities.map((a) => a.externalId), ['r1', 'r2']);
      expect(activities[0].kcal, 312);
      expect(activities[0].distanceMeters, 5000);
      expect(activities[0].source, 'health');
      expect(activities[1].type, 'yoga');
      expect(activities[1].kcal, 150, reason: '2.5 METs x 60 kcal/h x 1 h');
    });
  });

  group('provider', () {
    setUpAll(useFfiDatabase);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await resetDatabase();
    });

    test('connect, refresh, import once, export, disconnect', () async {
      final fake = FakeHealth();
      final now = DateTime.now();
      fake.records = [
        HealthWorkoutRecord(
            id: 'hc-1', type: 'RUNNING', start: now.subtract(const Duration(hours: 3)),
            end: now.subtract(const Duration(hours: 2)), kcal: 600, source: 'com.garmin'),
      ];
      fake.weight = (now.subtract(const Duration(days: 1)), 72.5);

      final health = HealthProvider(fake);
      await health.ready;
      expect(health.connected, isFalse, reason: 'opt-in');
      expect(await health.refresh(body: const BodyMetrics()), 0, reason: 'nothing read before connecting');

      expect(await health.connect(), isTrue);
      expect(await health.refresh(body: const BodyMetrics()), 1);
      expect(health.today?.steps, 8000);
      expect(health.weekSteps, hasLength(7));
      expect((await ActivityRepository.instance.getActivities(since: now.subtract(const Duration(days: 1)))).single.kcal,
          600);
      final weights = await ProfileRepository.instance.getBodyWeights();
      expect(weights.single.weightKg, 72.5);
      expect(weights.single.source, 'health');

      expect(await health.refresh(body: const BodyMetrics()), 0, reason: 'already imported');
      expect(await ProfileRepository.instance.getBodyWeights(), hasLength(1), reason: 'one weight per day');

      // The setting survives a restart.
      final again = HealthProvider(fake);
      await again.ready;
      expect(again.connected, isTrue);

      await health.exportActivity(Activity(
          id: 'a', type: 'cycling', startedAt: now, durationSeconds: 3600, distanceMeters: 20000, kcal: 500));
      await health.exportActivity(Activity(
          id: 'b', type: 'running', startedAt: now, durationSeconds: 600, kcal: 90, source: 'health'));
      await health.exportWorkout(Workout(
          id: 'w', name: 'Push Day', startedAt: now, durationSeconds: 3600, totalVolume: 1, kcal: 250));
      expect(fake.written, [
        {'type': 'BIKING', 'kcal': 500.0, 'distance': 20000.0, 'title': 'Cycling'},
        {'type': 'STRENGTH_TRAINING', 'kcal': 250.0, 'distance': null, 'title': 'Push Day'},
      ], reason: 'imported activities are not written back');

      await health.disconnect();
      expect(health.connected, isFalse);
      expect(fake.granted, isFalse);
    });

    test('missing Health Connect opens the install page', () async {
      final fake = FakeHealth()..currentStatus = HealthStatus.notInstalled;
      final health = HealthProvider(fake);
      await health.ready;
      expect(await health.connect(), isFalse);
      expect(fake.installed, isTrue);
    });

    test('access taken away in Health Connect turns the link off', () async {
      final fake = FakeHealth();
      final health = HealthProvider(fake);
      await health.ready;
      await health.connect();
      fake.granted = false;
      expect(await health.refresh(body: const BodyMetrics()), 0);
      expect(health.connected, isFalse);
      expect(health.error, isNotNull);
    });
  });
}
