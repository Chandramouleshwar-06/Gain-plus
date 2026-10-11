import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/workout/overload.dart';
import 'package:gain_plus/models/workout.dart';
import 'package:gain_plus/utils/units.dart';

void main() {
  List<SetEntry> sets(List<(double, int)> values) => [
        for (var i = 0; i < values.length; i++)
          SetEntry(id: '$i', position: i, weight: values[i].$1, reps: values[i].$2),
      ];

  test('adds weight once every set reached the target reps', () {
    final s = suggestNext(sets([(80, 10), (80, 10), (80, 11)]), targetReps: 10);
    expect(s!.increase, isTrue);
    expect(s.weight, 82.5);
    expect(s.message, contains('82.5 kg'));
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

  test('lower-body lifts go up in bigger steps', () {
    expect(isLowerBody(exerciseName: 'Squat (Barbell)', muscleGroup: 'Legs'), isTrue);
    expect(isLowerBody(exerciseName: 'Deadlift (Barbell)', muscleGroup: 'Back'), isTrue);
    expect(isLowerBody(exerciseName: 'Bench Press (Barbell)', muscleGroup: 'Chest'), isFalse);
    final s = suggestNext(sets([(100, 5), (100, 5)]), targetReps: 5, lowerBody: true);
    expect(s!.weight, 105);
  });

  test('in lb, steps are 5 / 10 lb from the rounded lb weight', () {
    const lb = Units.lb();
    final s = suggestNext(sets([(lb.toKg(135), 8), (lb.toKg(135), 8)]), targetReps: 8, units: lb);
    expect(lb.number(s!.weight), '140');
    expect(s.message, contains('140 lb'));
    final legs = suggestNext(sets([(lb.toKg(225), 5)]), targetReps: 5, lowerBody: true, units: lb);
    expect(lb.number(legs!.weight), '235');
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

  test('unit conversions round-trip and format', () {
    const lb = Units.lb();
    expect(lb.number(lb.toKg(135)), '135');
    expect(lb.weight(100), '220.5 lb');
    expect(lb.volume(lb.toKg(2150)), '2150 lb');
    expect(lb.volume(lb.toKg(27300)), '27.3k lb');
    expect(const Units.kg().weight(82.5), '82.5 kg');
  });
}
