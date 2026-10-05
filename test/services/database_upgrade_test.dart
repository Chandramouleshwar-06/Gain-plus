import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a v4 database containing the duplicate exercises that older
/// upgrades produced, then checks that opening it with DatabaseService
/// merges them.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v4 -> v5 merges duplicate exercises and keeps references', () async {
    final path = join(await getDatabasesPath(), 'gym_tracker.db');
    await deleteDatabase(path);

    final old = await openDatabase(path, version: 4, onCreate: (db, _) async {
      await db.execute('CREATE TABLE workouts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, duration INTEGER NOT NULL, totalVolume REAL NOT NULL)');
      await db.execute('CREATE TABLE exercise_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, workoutId INTEGER NOT NULL, exerciseId INTEGER NOT NULL, exerciseName TEXT NOT NULL)');
      await db.execute('CREATE TABLE set_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, exerciseEntryId INTEGER NOT NULL, weight REAL NOT NULL, reps INTEGER NOT NULL, completed INTEGER NOT NULL)');
      await db.execute('CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, exerciseIds TEXT NOT NULL)');
      await db.execute('CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, muscleGroup TEXT NOT NULL, notes TEXT NOT NULL)');
      await db.execute('CREATE TABLE schedules (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, planId INTEGER NOT NULL)');
    });
    Future<void> addExercise(int id, String name) =>
        old.insert('exercises', {'id': id, 'name': name, 'muscleGroup': 'Chest', 'notes': ''});
    await addExercise(1, 'Bench Press (Barbell)');
    await addExercise(2, 'Squat (Barbell)');
    await addExercise(3, 'Bench Press (Barbell)'); // duplicate of 1
    await old.insert('workouts', {'id': 1, 'date': '2026-10-01T10:00:00', 'duration': 30, 'totalVolume': 1000});
    await old.insert('exercise_entries', {'id': 1, 'workoutId': 1, 'exerciseId': 3, 'exerciseName': 'Bench Press (Barbell)'});
    await old.insert('workout_plans', {'id': 1, 'name': 'Mine', 'exerciseIds': '3,2,1'});
    await old.close();

    final db = await DatabaseService.instance.database;

    final names = (await db.query('exercises')).map((e) => e['name']).toList();
    expect(names.toSet().length, names.length, reason: 'exercise names should be unique');

    final entry = (await db.query('exercise_entries', where: 'id = 1')).single;
    expect(entry['exerciseId'], 1, reason: 'history should point at the kept exercise');

    final plan = (await db.query('workout_plans', where: 'id = 1')).single;
    expect(plan['exerciseIds'], '1,2', reason: 'plan keeps order and drops the merged duplicate');

    expect(
      () => db.insert('exercises', {'name': 'Squat (Barbell)', 'muscleGroup': 'Legs', 'notes': ''}),
      throwsA(isA<DatabaseException>()),
    );
  });
}
