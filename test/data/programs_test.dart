import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/programs.dart';
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/data/sync_columns.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/plans/plans_provider.dart';
import 'package:gain_plus/models/workout.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('every program exercise is a built-in exercise', () {
    final names = seedExercises.map((e) => e.name).toSet();
    for (final program in programs) {
      for (final day in program.days) {
        for (final e in day.exercises) {
          expect(names, contains(e.name), reason: '${program.name} / ${day.name}');
        }
      }
    }
  });

  test('installing a program creates its plans and schedules days in rotation', () async {
    final provider = PlansProvider();
    await provider.loadPlans();
    final before = provider.plans.length;

    final program = programs.firstWhere((p) => p.id == 'strength-5x5');
    final scheduled = await provider.installProgram(
      program,
      weekdays: [1, 3, 5],
      weeks: 2,
      time: const TimeOfDay(hour: 7, minute: 30),
    );

    expect(provider.plans.length, before + 2);
    final a = provider.plans.firstWhere((p) => p.name == '5×5 Workout A');
    expect(a.items.map((i) => (i.targetSets, i.targetReps)), everyElement((5, 5)));

    expect(scheduled, 6, reason: '3 days a week for 2 weeks');
    final entries = provider.schedules.values.toList()..sort((x, y) => x.date.compareTo(y.date));
    final names = entries.map((e) => provider.planById(e.planId)!.name).toList();
    expect(names.take(3), ['5×5 Workout A', '5×5 Workout B', '5×5 Workout A']);
    expect(entries.first.reminderMinutes, 7 * 60 + 30);
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
