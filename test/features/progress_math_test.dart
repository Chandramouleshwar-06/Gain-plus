import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/progress/progress_provider.dart';
import 'package:gain_plus/utils/strength.dart';
import 'package:gain_plus/utils/format.dart';
import 'package:gain_plus/widgets/charts.dart';

void main() {
  test('chart axis steps are round numbers', () {
    expect(niceInterval(325), 500);
    expect(niceInterval(180), 200);
    expect(niceInterval(2100), 2500);
    expect(niceInterval(40), 50);
    expect(formatVolume(975), '975 kg');
    expect(formatVolume(12400), '12.4 t');
  });

  test('estimated 1RM uses Epley and passes singles through', () {
    expect(estimateOneRepMax(100, 1), 100);
    expect(estimateOneRepMax(100, 10), closeTo(133.3, 0.1));
    expect(estimateOneRepMax(0, 5), 0);
  });

  test('weekly volume buckets workouts into Monday-start weeks', () {
    final now = DateTime(2026, 10, 10); // Saturday
    final weeks = ProgressProvider.calculateWeeklyVolume([
      (DateTime(2026, 10, 5, 18), 1000), // Monday this week
      (DateTime(2026, 10, 9, 7), 500), // Friday this week
      (DateTime(2026, 10, 4, 20), 300), // Sunday last week
      (DateTime(2026, 8, 1), 9999), // too old
    ], now, weeks: 4);

    expect(weeks.map((w) => w.$1), [
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 28),
      DateTime(2026, 10, 5),
    ]);
    expect(weeks.map((w) => w.$2), [0, 0, 300, 1500]);
  });

  test('lift summaries keep the heaviest set and the best e1RM separately', () {
    final lifts = ProgressProvider.calculateLiftSummaries([
      SetRecord('bench', 'Bench', 100, 1),
      SetRecord('bench', 'Bench', 90, 8), // e1RM 114 beats the single
      SetRecord('squat', 'Squat', 140, 5),
    ]);
    expect(lifts.first.name, 'Squat', reason: 'sorted by best e1RM');
    final bench = lifts.firstWhere((l) => l.exerciseId == 'bench');
    expect([bench.prWeight, bench.prReps], [100.0, 1]);
    expect(bench.bestE1rm, closeTo(114, 0.1));
  });

  test('bodyweight lifts use best reps and skip empty sets', () {
    final lifts = ProgressProvider.calculateLiftSummaries([
      SetRecord('pushups', 'Push Ups', 0, 0),
      SetRecord('pushups', 'Push Ups', 0, 15),
      SetRecord('pushups', 'Push Ups', 0, 22),
      SetRecord('empty', 'Empty', 0, 0),
    ]);
    expect(lifts.single.isBodyweight, isTrue);
    expect(lifts.single.prReps, 22);
  });
}
