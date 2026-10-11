import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/workout/workout_provider.dart';
import 'package:gain_plus/models/workout.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('v6 database upgrades to v7: sets default to working sets, new tables exist', () async {
    final v6 = await openDatabase(await testDbPath(), version: 6, onCreate: (db, _) async {
      await DatabaseService.createV6SchemaForTest(db);
    });
    await v6.insert('workout_sets', {
      'id': 's1',
      'workoutExerciseId': 'e1',
      'position': 0,
      'weight': 80.0,
      'reps': 5,
      'updatedAt': 1,
      'dirty': 0,
    });
    await v6.close();

    final db = await DatabaseService.instance.database;
    final set = (await db.query('workout_sets')).single;
    expect(set['setType'], 'normal');
    expect(set['rpe'], isNull);

    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'")).map((r) => r['name']);
    expect(tables, containsAll(['programs', 'program_workouts']));
    final profileCols = (await db.rawQuery('PRAGMA table_info(profile)')).map((r) => r['name']);
    expect(profileCols, containsAll(['equipment', 'sex', 'activityLevel']));
  });

  test('set types and RPE are saved; warm-ups are left out of volume and PRs', () async {
    final provider = WorkoutProvider();
    provider.startWorkout(null, 'Bench day', [
      WorkoutExercise(exerciseId: 'bench', name: 'Bench', sets: [WorkoutSet(), WorkoutSet()]),
    ]);
    final bench = provider.exercises.first;
    provider.updateSet(bench, 0, 100, 5); // heavy, but marked as a warm-up
    provider.setSetType(bench, 0, SetType.warmup);
    provider.toggleSetComplete(bench, 0);
    provider.updateSet(bench, 1, 60, 10);
    provider.setRpe(bench, 1, 8.5);
    provider.toggleSetComplete(bench, 1);
    await provider.finishWorkout();

    final repo = WorkoutRepository.instance;
    final saved = (await repo.getRecent()).single;
    expect(saved.totalVolume, 600, reason: 'only the working set counts');

    final sets = (await repo.getWithDetails(saved.id))!.exercises.single.sets;
    expect(sets.map((s) => s.setType), [SetType.warmup, SetType.normal]);
    expect(sets.last.rpe, 8.5);

    final records = await repo.getAllSets();
    expect(records.map((r) => r.weight), [60.0], reason: 'warm-up excluded from PR data');
  });
}
