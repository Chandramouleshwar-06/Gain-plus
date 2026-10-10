import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/workout/overload.dart';
import 'package:gain_plus/models/workout.dart';

void main() {
  List<SetEntry> sets(List<(double, int)> values) => [
        for (var i = 0; i < values.length; i++)
          SetEntry(id: '$i', position: i, weight: values[i].$1, reps: values[i].$2),
      ];

  test('adds weight once every set reached the target reps', () {
    final s = suggestNext(sets([(80, 10), (80, 10), (80, 11)]), targetReps: 10);
    expect(s!.increase, isTrue);
    expect(s.weight, 82.5);
  });

  test('stays at the weight when a set fell short', () {
    final s = suggestNext(sets([(80, 10), (80, 9), (80, 8)]), targetReps: 10);
    expect(s!.increase, isFalse);
    expect(s.weight, 80);
  });

  test('uses the heaviest weight from last time', () {
    final s = suggestNext(sets([(60, 12), (80, 10), (80, 10)]), targetReps: 10);
    expect(s!.weight, 82.5);
  });

  test('lower-body lifts go up by 5 kg', () {
    expect(weightIncrement(exerciseName: 'Squat (Barbell)', muscleGroup: 'Legs'), 5);
    expect(weightIncrement(exerciseName: 'Deadlift (Barbell)', muscleGroup: 'Back'), 5);
    expect(weightIncrement(exerciseName: 'Bench Press (Barbell)', muscleGroup: 'Chest'), 2.5);
    final s = suggestNext(sets([(100, 5), (100, 5)]), targetReps: 5, increment: 5);
    expect(s!.weight, 105);
  });

  test('no suggestion for bodyweight-only or empty history', () {
    expect(suggestNext([]), isNull);
    expect(suggestNext(sets([(0, 12), (0, 10)])), isNull);
  });

  test('without a target it suggests matching last time', () {
    final s = suggestNext(sets([(50, 8), (50, 8)]));
    expect(s!.increase, isFalse);
    expect(s.weight, 50);
  });
}
