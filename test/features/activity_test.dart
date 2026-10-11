import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/activity_repository.dart';
import 'package:gain_plus/data/activity_types.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/activity/activity_provider.dart';
import 'package:gain_plus/features/nutrition/nutrition_provider.dart';
import 'package:gain_plus/models/activity.dart';
import 'package:gain_plus/models/workout.dart';

import '../helpers/test_db.dart';

void main() {
  group('calorie estimate', () {
    test('METs follow running speed, between and beyond the table', () {
      final running = activityType('running');
      const hour = Duration(hours: 1);
      // 10 km/h is between 9.7 (9.8 METs) and 11.3 (11.0 METs).
      expect(metFor(running, duration: hour, distanceKm: 10), closeTo(9.8 + 1.2 * 0.3 / 1.6, 0.001));
      expect(metFor(running, duration: hour, distanceKm: 3), 6.0, reason: 'slower than the table');
      expect(metFor(running, duration: hour, distanceKm: 25), 16.0, reason: 'faster than the table');
      expect(metFor(running, duration: hour), running.met, reason: 'no distance');
      expect(metFor(activityType('yoga'), duration: hour, distanceKm: 5), 2.5, reason: 'speed ignored');
    });

    test('uses resting burn from height, age and sex when known', () {
      // 80 kg, 180 cm, 30, male: BMR 1780 kcal/day = 74.17 kcal/h.
      const body = BodyMetrics(weightKg: 80, heightCm: 180, age: 30, sex: 'male');
      expect(body.restingKcalPerHour, closeTo(1780 / 24, 0.001));
      expect(estimateKcal(met: 2.5, body: body, duration: const Duration(hours: 1)), 185);

      // Only weight: the textbook 1 kcal per kg per hour.
      expect(estimateKcal(met: 8, body: const BodyMetrics(weightKg: 60), duration: const Duration(minutes: 30)), 240);
      // Nothing: 70 kg.
      expect(estimateKcal(met: 10, body: const BodyMetrics(), duration: const Duration(minutes: 30)), 350);
    });

    test('unknown type codes fall back to Other', () {
      expect(activityType('underwater-hockey').code, 'other');
    });
  });

  group('storage', () {
    setUpAll(useFfiDatabase);
    setUp(resetDatabase);

    test('burned per day adds activities and gym workouts', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 7);
      final provider = ActivityProvider();
      await provider.save(Activity(id: 'a1', type: 'running', startedAt: today, durationSeconds: 1800, distanceMeters: 5000, kcal: 350));
      await provider.save(Activity(
          id: 'a2', type: 'swimming', startedAt: today.subtract(const Duration(days: 1)), durationSeconds: 1800, kcal: 250));
      await WorkoutRepository.instance.save(Workout(
          id: 'w1', name: 'Push', startedAt: today.add(const Duration(hours: 2)), durationSeconds: 3600, totalVolume: 1000, kcal: 260));

      await provider.load();
      expect(provider.recent.map((a) => a.id), ['a1', 'a2'], reason: 'newest first');
      expect(provider.today.map((a) => a.id), ['a1']);
      expect(provider.burnedToday, 350 + 260);
      expect(await provider.burnedOn(today.subtract(const Duration(days: 1))), 250);

      final nutrition = NutritionProvider();
      await nutrition.load();
      expect(nutrition.burned, 610, reason: 'shown next to calories eaten');

      // Edits keep the id; deletes are soft and drop out of the totals.
      await provider.save(Activity(id: 'a1', type: 'running', startedAt: today, durationSeconds: 2400, kcal: 400));
      expect(provider.recent.first.durationSeconds, 2400);
      await provider.delete('a1');
      expect(provider.burnedToday, 260);
      expect(provider.recent.map((a) => a.id), ['a2']);
    });

    test('imported health records are remembered, even after deleting', () async {
      final repo = ActivityRepository.instance;
      await repo.save(Activity(
          id: 'h1', type: 'walking', startedAt: DateTime.now(), durationSeconds: 600, kcal: 40, source: 'health', externalId: 'hc-123'));
      await repo.delete('h1');
      expect(await repo.importedExternalIds(), {'hc-123'});
    });
  });
}
