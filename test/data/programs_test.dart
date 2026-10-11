import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/programs.dart' as programs_data;
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/data/sync_columns.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/plans/plans_provider.dart';
import 'package:gain_plus/features/plans/programs_provider.dart';
import 'package:gain_plus/models/workout.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('every program exercise is a built-in exercise', () {
    final names = seedExercises.map((e) => e.name).toSet();
    for (final program in programs_data.programs) {
      for (final day in program.days) {
        for (final e in day.exercises) {
          expect(names, contains(e.name), reason: '${program.name} / ${day.name}');
        }
      }
    }
  });

  test('a ready-made program becomes an editable program; starting schedules it in rotation', () async {
    final plans = PlansProvider();
    final programs = ProgramsProvider();
    await plans.loadPlans();
    final before = plans.plans.length;

    final id = await programs.copyBuiltin(programs_data.programs.firstWhere((p) => p.id == 'strength-5x5'));
    await plans.loadPlans();
    expect(plans.plans.length, before + 2);
    final program = programs.byId(id)!;
    expect(program.planIds, hasLength(2));
    expect(program.isActive, isFalse);

    await programs.save(id: id, name: program.name, weekdays: [1, 3, 5], weeks: 2, planIds: program.planIds);
    final count = await programs.start(programs.byId(id)!, from: DateTime(2026, 10, 5), reminderMinutes: 7 * 60 + 30);
    await plans.loadPlans();
    expect(count, 6, reason: '3 days a week for 2 weeks');
    expect(programs.byId(id)!.startedOn, DateTime(2026, 10, 5));

    final entries = plans.schedules.values.toList()..sort((x, y) => x.date.compareTo(y.date));
    expect(entries.map((e) => plans.planById(e.planId)!.name).take(3), ['5×5 Workout A', '5×5 Workout B', '5×5 Workout A']);
    expect(entries.every((e) => e.programId == id && e.reminderMinutes == 7 * 60 + 30), isTrue);
  });

  test('last sets come from the most recent workout with that exercise', () async {
    final repo = WorkoutRepository.instance;
    final bench = builtinExerciseId('Bench Press (Barbell)');
    Future<void> save(DateTime when, double weight) => repo.save(Workout(
          id: newId(),
          name: 'Push',
          startedAt: when,
          durationSeconds: 60,
          totalVolume: weight * 5,
          exercises: [
            ExerciseEntry(id: newId(), exerciseId: bench, exerciseName: 'Bench', position: 0, sets: [
              SetEntry(id: newId(), position: 0, weight: weight, reps: 5),
            ]),
          ],
        ));
    await save(DateTime(2026, 10, 1), 80);
    await save(DateTime(2026, 10, 8), 82.5);
    await save(DateTime(2026, 9, 20), 75);

    final last = await repo.getLastSets(bench);
    expect(last.single.weight, 82.5);
    expect(await repo.getLastSets('never-done'), isEmpty);
  });
}
