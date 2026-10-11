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

  test('ticking a set starts the rest timer; skip and adjust work', () async {
    final provider = WorkoutProvider();
    provider.startWorkout(null, 'Arms', [
      WorkoutExercise(exerciseId: 'ex-1', name: 'Curl', sets: [WorkoutSet(), WorkoutSet()]),
    ]);
    final curl = provider.exercises.first;

    provider.toggleSetComplete(curl, 0);
    expect(provider.isResting, isFalse, reason: 'no rest length given (timer off)');

    provider.toggleSetComplete(curl, 1, restSeconds: 90);
    expect(provider.isResting, isTrue);
    final firstEnd = provider.restEndsAt!;
    expect(firstEnd.difference(DateTime.now()).inSeconds, closeTo(90, 1));

    provider.adjustRest(15);
    expect(provider.restEndsAt, firstEnd.add(const Duration(seconds: 15)));
    expect(provider.restTotalSeconds, 105);

    provider.adjustRest(-200);
    expect(provider.isResting, isFalse, reason: 'removing more than is left ends the rest');

    provider.toggleSetComplete(curl, 1); // untick
    provider.toggleSetComplete(curl, 1, restSeconds: 60);
    provider.endRest();
    expect(provider.isResting, isFalse);
    await provider.discardWorkout();
  });

  test('a running rest survives a restart', () async {
    final provider = WorkoutProvider();
    provider.startWorkout(null, 'Arms', [
      WorkoutExercise(exerciseId: 'ex-1', name: 'Curl', sets: [WorkoutSet()]),
    ]);
    provider.toggleSetComplete(provider.exercises.first, 0, restSeconds: 120);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final restored = WorkoutProvider();
    await restored.restore();
    expect(restored.isResting, isTrue);
    expect(restored.restTotalSeconds, 120);
  });

  test('ticked sets with no reps are not saved', () async {
    final provider = WorkoutProvider();
    provider.startWorkout(null, 'Mixed', [
      WorkoutExercise(exerciseId: 'burpees', name: 'Burpees', sets: [WorkoutSet(), WorkoutSet()]),
    ]);
    final burpees = provider.exercises.first;
    provider.toggleSetComplete(burpees, 0); // ticked, left empty
    expect(provider.completedSetCount, 0, reason: 'so finishing offers to discard');

    provider.updateSet(burpees, 1, 0, 12);
    provider.toggleSetComplete(burpees, 1);
    await provider.finishWorkout();
    final saved = (await WorkoutRepository.instance.getRecent()).single;
    final details = (await WorkoutRepository.instance.getWithDetails(saved.id))!;
    expect(details.exercises.single.sets.map((s) => s.reps), [12]);
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
