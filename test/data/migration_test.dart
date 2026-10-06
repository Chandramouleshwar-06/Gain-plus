import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/exercise_repository.dart';
import 'package:gain_plus/data/plan_repository.dart';
import 'package:gain_plus/data/schedule_repository.dart';
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// Builds a v4 database (integer IDs, comma-separated plan exercises,
/// unpadded schedule dates, duplicate exercises from old upgrades) and
/// checks that opening it converts everything to v6.
Future<void> _createLegacyV4Database() async {
  final db = await openDatabase(await testDbPath(), version: 4, onCreate: (db, _) async {
    await db.execute('CREATE TABLE workouts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, duration INTEGER NOT NULL, totalVolume REAL NOT NULL)');
    await db.execute('CREATE TABLE exercise_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, workoutId INTEGER NOT NULL, exerciseId INTEGER NOT NULL, exerciseName TEXT NOT NULL, FOREIGN KEY (workoutId) REFERENCES workouts (id))');
    await db.execute('CREATE TABLE set_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, exerciseEntryId INTEGER NOT NULL, weight REAL NOT NULL, reps INTEGER NOT NULL, completed INTEGER NOT NULL)');
    await db.execute('CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, exerciseIds TEXT NOT NULL)');
    await db.execute('CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, muscleGroup TEXT NOT NULL, notes TEXT NOT NULL)');
    await db.execute('CREATE TABLE schedules (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, planId INTEGER NOT NULL)');
  });

  Future<void> exercise(int id, String name) =>
      db.insert('exercises', {'id': id, 'name': name, 'muscleGroup': 'Chest', 'notes': ''});
  await exercise(1, 'Bench Press (Barbell)');
  await exercise(2, 'Squat (Barbell)');
  await exercise(3, 'Bench Press (Barbell)'); // duplicate from an old upgrade
  await exercise(4, 'My Curl');

  await db.insert('workout_plans', {'id': 1, 'name': 'Push (Chest/Shoulders/Triceps)', 'exerciseIds': '3,2,1'});
  await db.insert('workout_plans', {'id': 2, 'name': 'Mine', 'exerciseIds': '4,1,99'});

  // Finished at 10:30 after 30 minutes.
  await db.insert('workouts', {'id': 1, 'date': '2026-10-01T10:30:00.000', 'duration': 30, 'totalVolume': 1265});
  await db.insert('exercise_entries', {'id': 1, 'workoutId': 1, 'exerciseId': 3, 'exerciseName': 'Bench Press (Barbell)'});
  await db.insert('exercise_entries', {'id': 2, 'workoutId': 1, 'exerciseId': 4, 'exerciseName': 'My Curl'});
  await db.insert('set_entries', {'exerciseEntryId': 1, 'weight': 80.0, 'reps': 8, 'completed': 1});
  await db.insert('set_entries', {'exerciseEntryId': 1, 'weight': 85.0, 'reps': 5, 'completed': 1});
  await db.insert('set_entries', {'exerciseEntryId': 1, 'weight': 90.0, 'reps': 1, 'completed': 0});
  await db.insert('set_entries', {'exerciseEntryId': 2, 'weight': 20.0, 'reps': 10, 'completed': 1});

  await db.insert('schedules', {'date': '2026-1-5', 'planId': 2});
  await db.close();
}

void main() {
  setUpAll(useFfiDatabase);

  setUp(() async {
    await resetDatabase();
    await _createLegacyV4Database();
  });

  test('exercises are merged by name and built-ins get fixed IDs', () async {
    final exercises = await ExerciseRepository.instance.getAll();
    final names = exercises.map((e) => e.name).toList();
    expect(names.toSet().length, names.length);
    expect(exercises.length, seedExercises.length + 1); // + My Curl

    final bench = exercises.firstWhere((e) => e.name == 'Bench Press (Barbell)');
    expect(bench.id, builtinExerciseId('Bench Press (Barbell)'));
    expect(bench.isCustom, isFalse);
    expect(exercises.firstWhere((e) => e.name == 'My Curl').isCustom, isTrue);
  });

  test('plans keep their exercise order; a built-in name takes the built-in ID', () async {
    final plans = await PlanRepository.instance.getAll();
    final push = plans.firstWhere((p) => p.name == 'Push (Chest/Shoulders/Triceps)');
    expect(push.id, builtinPlanId('push'));
    expect(push.exerciseIds, [
      builtinExerciseId('Bench Press (Barbell)'),
      builtinExerciseId('Squat (Barbell)'),
    ]);

    final mine = plans.firstWhere((p) => p.name == 'Mine');
    expect(mine.exerciseIds.length, 2, reason: 'unknown exercise 99 is dropped');
    expect(mine.exerciseIds.last, builtinExerciseId('Bench Press (Barbell)'));

    // Built-in plans the user never had are seeded too.
    expect(plans.map((p) => p.id), contains(builtinPlanId('pull')));
  });

  test('workouts keep their exercises and completed sets', () async {
    final workouts = await WorkoutRepository.instance.getRecent();
    expect(workouts, hasLength(1));
    final w = workouts.single;
    expect(w.name, 'Workout');
    expect(w.durationSeconds, 30 * 60);
    expect(w.startedAt, DateTime(2026, 10, 1, 10, 0));

    final details = (await WorkoutRepository.instance.getWithDetails(w.id))!;
    expect(details.exercises.map((e) => e.exerciseName), ['Bench Press (Barbell)', 'My Curl']);
    expect(details.exercises.first.exerciseId, builtinExerciseId('Bench Press (Barbell)'));
    expect(details.exercises.first.sets.map((s) => '${s.weight}x${s.reps}'), ['80.0x8', '85.0x5'],
        reason: 'the uncompleted 90 kg set is dropped');
  });

  test('schedule dates are padded and point at the new plan ID', () async {
    final schedules = await ScheduleRepository.instance.getAll();
    final plans = await PlanRepository.instance.getAll();
    expect(schedules.keys, ['2026-01-05']);
    expect(schedules['2026-01-05']!.planId, plans.firstWhere((p) => p.name == 'Mine').id);
  });

  test('legacy tables are removed and migrated rows are marked for upload', () async {
    final db = await DatabaseService.instance.database;
    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    for (final legacy in ['legacy_exercises', 'legacy_workouts', 'legacy_schedules', 'workout_plans', 'exercise_entries', 'set_entries']) {
      expect(tables, isNot(contains(legacy)));
    }

    final dirtyWorkouts = await db.query('workouts', where: 'dirty = 1');
    expect(dirtyWorkouts, hasLength(1));
    final cleanSeed = await db.query('exercises',
        where: 'id = ? AND dirty = 0', whereArgs: [builtinExerciseId('Leg Press')]);
    expect(cleanSeed, hasLength(1), reason: 'untouched seed rows are not uploaded');
  });
}
