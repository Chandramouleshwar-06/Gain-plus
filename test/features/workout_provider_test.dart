import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/progress/progress_provider.dart';
import 'package:gain_plus/features/workout/workout_provider.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('an in-progress workout survives a restart', () async {
    final provider = WorkoutProvider();
    provider.startWorkout('plan-1', 'Push Day', [
      WorkoutExercise(exerciseId: 'ex-1', name: 'Bench', sets: [WorkoutSet(), WorkoutSet()]),
    ]);
    final exercise = provider.exercises.first;
    provider.updateSet(exercise, 0, 82.5, 6);
    provider.toggleSetComplete(exercise, 0);
    await Future<void>.delayed(const Duration(milliseconds: 600)); // let the debounced save run

    final restored = WorkoutProvider();
    await restored.restore();
    expect(restored.isWorkoutActive, isTrue);
    expect(restored.activePlanName, 'Push Day');
    expect(restored.startTime, provider.startTime!.copyWith(microsecond: 0));
    final set = restored.exercises.single.sets.first;
    expect([set.weight, set.reps, set.completed], [82.5, 6, true]);
  });

  test('finishing saves only completed sets and clears the stored workout', () async {
    final provider = WorkoutProvider();
    provider.startWorkout('plan-1', 'Push Day', [
      WorkoutExercise(exerciseId: 'ex-1', name: 'Bench', sets: [WorkoutSet(), WorkoutSet()]),
      WorkoutExercise(exerciseId: 'ex-2', name: 'Dips', sets: [WorkoutSet()]),
    ]);
    final bench = provider.exercises.first;
    provider.updateSet(bench, 0, 80, 8);
    provider.toggleSetComplete(bench, 0);

    await provider.finishWorkout();
    expect(provider.isWorkoutActive, isFalse);
    expect(await ActiveWorkoutStore.instance.load(), isNull);

    final saved = (await WorkoutRepository.instance.getRecent()).single;
    expect(saved.name, 'Push Day');
    expect(saved.planId, 'plan-1');
    expect(saved.totalVolume, 640);
    final details = (await WorkoutRepository.instance.getWithDetails(saved.id))!;
    expect(details.exercises.map((e) => e.exerciseName), ['Bench'], reason: 'Dips had no completed sets');
  });

  test('streak counts consecutive days ending today or yesterday', () {
    final now = DateTime(2026, 10, 6, 20);
    DateTime day(int d, [int h = 9]) => DateTime(2026, 10, d, h);

    expect(ProgressProvider.calculateStreak([], now), 0);
    expect(ProgressProvider.calculateStreak([day(6), day(5), day(4), day(4, 18)], now), 3);
    expect(ProgressProvider.calculateStreak([day(5), day(4)], now), 2, reason: 'today not trained yet');
    expect(ProgressProvider.calculateStreak([day(4), day(3)], now), 0);
  });

  test('personal record is the heaviest set, ties broken by reps', () {
    final prs = ProgressProvider.calculatePersonalRecords([
      SetRecord('a', 'Bench', 80, 8),
      SetRecord('a', 'Bench', 85, 3),
      SetRecord('a', 'Bench', 85, 5),
      SetRecord('b', 'Squat', 100, 5),
    ]);
    expect([prs['Bench']!.weight, prs['Bench']!.reps], [85.0, 5]);
    expect(prs['Squat']!.weight, 100);
  });
}
