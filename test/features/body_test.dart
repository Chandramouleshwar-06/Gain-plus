import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/profile/profile_provider.dart';
import 'package:gain_plus/models/body.dart';
import 'package:gain_plus/models/profile.dart';
import 'package:gain_plus/services/photo_store.dart';
import 'package:gain_plus/utils/units.dart';

import '../helpers/test_db.dart';

void main() {
  test('lengths follow the weight unit', () {
    const kg = Units.kg();
    const lb = Units.lb();
    expect(kg.length(81.5), '81.5 cm');
    expect(lb.length(81.28), '32 in');
    expect(lb.toCm(32), closeTo(81.28, 0.001));
  });

  group('measurements', () {
    setUpAll(useFfiDatabase);
    setUp(resetDatabase);

    test('one value per site per day; latest and history per site', () async {
      final profile = ProfileProvider();
      await profile.load();
      final day1 = DateTime(2026, 9, 1);
      await profile.logMeasurements({'waist': 90, 'arm': 36}, date: day1);
      await profile.logMeasurements({'waist': 89}, date: day1); // corrected
      await profile.logMeasurements({'waist': 86, 'body_fat': 18.5}, date: DateTime(2026, 10, 1));

      expect(profile.measurementsFor('waist').map((m) => m.value), [89, 86]);
      expect(profile.latestMeasurement('arm'), 36);
      expect(profile.latestMeasurement('body_fat'), 18.5);
      expect(profile.latestMeasurement('calf'), isNull);

      await profile.deleteMeasurement(profile.measurementsFor('waist').last.id);
      expect(profile.latestMeasurement('waist'), 89);
    });

    test('measurement goals track the latest value, going down or up', () async {
      final profile = ProfileProvider();
      await profile.load();
      await profile.logMeasurements({'waist': 90, 'arm': 36});
      await profile.addGoal(type: Goal.typeMeasurement, site: 'waist', targetValue: 80, startValue: 90);
      await profile.addGoal(type: Goal.typeMeasurement, site: 'arm', targetValue: 40, startValue: 36);

      final waist = profile.goals.firstWhere((g) => g.site == 'waist');
      expect(waist.type, Goal.typeMeasurement, reason: 'saved and loaded with its site');

      await profile.logMeasurements({'waist': 85, 'arm': 40});
      final waistNow = profile.currentValue(waist, {})!;
      expect(ProfileProvider.goalProgress(waist, waistNow), 0.5);

      final achieved = await profile.markAchievedGoals({});
      expect(achieved.map((g) => g.site), ['arm']);
      expect(profile.goals.firstWhere((g) => g.site == 'arm').achievedAt, isNotNull);
    });
  });

  group('photos', () {
    late Directory temp;
    late PhotoStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('gainplus_photos');
      store = PhotoStore(baseDir: () async => Directory('${temp.path}/progress_photos'));
    });
    tearDown(() => temp.delete(recursive: true));

    test('stored with date and pose in the name, listed newest first, deleted', () async {
      final source = File('${temp.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      await store.add(source, date: DateTime(2026, 9, 1), pose: 'side');
      final front = await store.add(source, date: DateTime(2026, 10, 1), pose: 'front');
      await store.add(source, date: DateTime(2026, 10, 1), pose: 'back');
      File('${temp.path}/progress_photos/random.txt').writeAsStringSync('ignored');

      final photos = await store.list();
      expect(photos.map((p) => '${p.date.month}-${p.pose}'), ['10-front', '10-back', '9-side']);
      expect(photos.first.id, front.id);

      await store.delete(front);
      expect(await store.list(), hasLength(2));

      await store.deleteAll();
      expect(await store.list(), isEmpty);
    });

    test('poses have labels', () {
      expect(photoPoses.map(poseLabel), ['Front', 'Side', 'Back']);
    });
  });
}
