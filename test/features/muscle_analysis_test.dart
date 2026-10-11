import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/muscles.dart';
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/features/progress/muscle_analysis.dart';
import 'package:gain_plus/models/exercise.dart';

void main() {
  final now = DateTime(2026, 10, 11, 18);
  MuscleSet set(int hoursAgo, List<Muscle> primary, [List<Muscle> secondary = const []]) =>
      MuscleSet(now.subtract(Duration(hours: hoursAgo)), (primary, secondary));

  test('every built-in exercise has muscle data', () {
    for (final e in seedExercises) {
      final muscles = musclesFor(Exercise(id: e.id, name: e.name, muscleGroup: e.muscleGroup, notes: ''));
      expect(muscles.$1, isNotEmpty, reason: e.name);
    }
  });

  test('custom exercises are mapped from their muscle group text', () {
    final (primary, secondary) =
        musclesFor(Exercise(id: 'x', name: 'Cable Row Thing', muscleGroup: 'Back/Biceps', notes: '', isCustom: true));
    expect(primary, containsAll([Muscle.lats, Muscle.upperBack]));
    expect(secondary, [Muscle.biceps]);
  });

  test('fatigue fades over the recovery window; secondary muscles count half', () {
    final fresh = muscleLoad([for (var i = 0; i < 6; i++) set(0, [Muscle.chest], [Muscle.triceps])], now);
    expect(fresh[Muscle.chest], 6);
    expect(fresh[Muscle.triceps], 3);
    expect(statusFor(recoveryFor(Muscle.chest, fresh)), RecoveryStatus.tired);

    final halfway = muscleLoad([for (var i = 0; i < 6; i++) set(36, [Muscle.chest])], now);
    expect(halfway[Muscle.chest], closeTo(3, 0.01), reason: 'chest recovers over 72 h');
    expect(statusFor(recoveryFor(Muscle.chest, halfway)), RecoveryStatus.recovering);

    final done = muscleLoad([set(80, [Muscle.chest])], now);
    expect(done[Muscle.chest], isNull);
    expect(statusFor(recoveryFor(Muscle.chest, done)), RecoveryStatus.fresh);
  });

  test('weekly sets credit primary groups fully and other groups half, last 7 days only', () {
    final totals = weeklyGroupSets([
      set(10, [Muscle.chest], [Muscle.frontDelts, Muscle.triceps]),
      set(10, [Muscle.chest], [Muscle.frontDelts, Muscle.triceps]),
      set(30, [Muscle.lats, Muscle.upperBack], [Muscle.biceps]), // both primaries are Back: one set
      set(24 * 9, [Muscle.quads]), // too old
    ], now);
    expect(totals['Chest'], 2);
    expect(totals['Shoulders'], 1);
    expect(totals['Arms'], 1.5);
    expect(totals['Back'], 1);
    expect(totals['Legs'], 0);
  });
}
