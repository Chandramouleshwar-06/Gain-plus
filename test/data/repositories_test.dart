import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/exercise_repository.dart';
import 'package:gain_plus/data/plan_repository.dart';
import 'package:gain_plus/data/profile_repository.dart';
import 'package:gain_plus/data/schedule_repository.dart';
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/data/sync_columns.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/models/profile.dart';
import 'package:gain_plus/models/workout.dart';
import 'package:gain_plus/services/database_service.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('fresh install seeds built-in exercises and plans in order', () async {
    final exercises = await ExerciseRepository.instance.getAll();
    expect(exercises, hasLength(seedExercises.length));

    final plans = await PlanRepository.instance.getAll();
    expect(plans, hasLength(seedPlans.length));
    final push = plans.firstWhere((p) => p.id == builtinPlanId('push'));
    expect(push.exerciseIds, seedPlans.first.exerciseNames.map(builtinExerciseId).toList());
  });

  test('custom exercise names must be unique', () async {
    final repo = ExerciseRepository.instance;
    expect(await repo.addCustom(name: 'Cable Fly', muscleGroup: 'Chest'), isNotNull);
    expect(await repo.addCustom(name: 'Cable Fly', muscleGroup: 'Chest'), isNull);
    expect(await repo.addCustom(name: 'Bench Press (Barbell)', muscleGroup: 'Chest'), isNull);
  });

  test('plan exercises append in order, skip duplicates and soft-delete', () async {
    final repo = PlanRepository.instance;
    final planId = await repo.create('Arms');
    final curl = builtinExerciseId('Bicep Curl (Dumbbell)');
    final dip = builtinExerciseId('Tricep Dip');

    await repo.addExercise(planId, curl);
    await repo.addExercise(planId, dip);
    await repo.addExercise(planId, curl);
    var plan = (await repo.getAll()).firstWhere((p) => p.id == planId);
    expect(plan.exerciseIds, [curl, dip]);

    await repo.removeExercise(planId, curl);
    plan = (await repo.getAll()).firstWhere((p) => p.id == planId);
    expect(plan.exerciseIds, [dip]);

    final db = await DatabaseService.instance.database;
    final removed = await db.query('plan_exercises',
        where: 'planId = ? AND exerciseId = ?', whereArgs: [planId, curl]);
    expect(removed.single['deletedAt'], isNotNull, reason: 'kept as a tombstone for sync');
    expect(removed.single['dirty'], 1);
  });

  test('scheduling a day replaces what was scheduled before', () async {
    final repo = ScheduleRepository.instance;
    final day = DateTime(2026, 10, 6);
    await repo.set(day, builtinPlanId('push'), reminderMinutes: 8 * 60);
    await repo.set(day, builtinPlanId('pull'));

    final schedules = await repo.getAll();
    expect(schedules, hasLength(1));
    expect(schedules['2026-10-06']!.planId, builtinPlanId('pull'));

    await repo.clear(day);
    expect(await repo.getAll(), isEmpty);
  });

  test('saved workouts round-trip with exercises, sets and stats', () async {
    final repo = WorkoutRepository.instance;
    final bench = builtinExerciseId('Bench Press (Barbell)');
    await repo.save(Workout(
      id: newId(),
      planId: builtinPlanId('push'),
      name: 'Push Day',
      startedAt: DateTime(2026, 10, 6, 18),
      durationSeconds: 3000,
      totalVolume: 1105,
      exercises: [
        ExerciseEntry(id: newId(), exerciseId: bench, exerciseName: 'Bench Press (Barbell)', position: 0, sets: [
          SetEntry(id: newId(), position: 0, weight: 82.5, reps: 6),
          SetEntry(id: newId(), position: 1, weight: 85, reps: 7),
        ]),
      ],
    ));

    final recent = await repo.getRecent();
    expect(recent.single.name, 'Push Day');
    final details = (await repo.getWithDetails(recent.single.id))!;
    expect(details.exercises.single.sets.map((s) => s.weight), [82.5, 85.0]);

    final stats = await repo.getStats();
    expect(stats.count, 1);
    expect(stats.totalVolume, 1105);

    final sets = await repo.getAllSets();
    expect(sets.map((s) => s.exerciseId).toSet(), {bench});
  });

  test('active workout store saves, loads and clears', () async {
    final store = ActiveWorkoutStore.instance;
    expect(await store.load(), isNull);
    await store.save('{"a":1}');
    await store.save('{"a":2}');
    expect(await store.load(), '{"a":2}');
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('profile, goals and body weights', () async {
    final repo = ProfileRepository.instance;
    expect(await repo.getProfile(), isNull);
    await repo.saveProfile(const Profile(name: 'CR', workoutsPerWeek: 4));
    expect((await repo.getProfile())!.workoutsPerWeek, 4);

    final goal = Goal(
      id: newId(),
      type: Goal.typeLift,
      exerciseId: builtinExerciseId('Bench Press (Barbell)'),
      targetValue: 100,
      deadline: DateTime(2027, 1, 31),
    );
    await repo.saveGoal(goal);
    final goals = await repo.getGoals();
    expect(goals.single.deadline, DateTime(2027, 1, 31));
    await repo.deleteGoal(goal.id);
    expect(await repo.getGoals(), isEmpty);

    await repo.addBodyWeight(DateTime(2026, 10, 5), 78.6);
    await repo.addBodyWeight(DateTime(2026, 10, 1), 79.1);
    final weights = await repo.getBodyWeights();
    expect(weights.map((w) => w.weightKg), [79.1, 78.6]);
  });
}
