import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/seed_data.dart';
import '../data/sync_columns.dart';
import '../utils/date_keys.dart';

/// Opens the app database and owns its schema and migrations. Reads and
/// writes go through the repositories in `lib/data/`.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  static const fileName = 'gym_tracker.db';
  static const schemaVersion = 6;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(fileName);
    return _database!;
  }

  /// Closes the database so the next access reopens it. For tests.
  @visibleForTesting
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedBuiltins(db);
      },
      onUpgrade: _upgradeDB,
    );
  }

  /// The v6 schema. Synced tables use UUID text IDs plus [syncColumnsSql].
  /// There are no SQLite foreign keys: deletes are soft (they set
  /// `deletedAt`), so the repositories delete child rows themselves.
  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        isCustom INTEGER NOT NULL DEFAULT 0,
        $syncColumnsSql
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_exercises_name ON exercises (name) WHERE deletedAt IS NULL');

    await db.execute('''
      CREATE TABLE plans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        $syncColumnsSql
      )
    ''');

    await db.execute('''
      CREATE TABLE plan_exercises (
        id TEXT PRIMARY KEY,
        planId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        position INTEGER NOT NULL,
        targetSets INTEGER NOT NULL DEFAULT 3,
        targetReps INTEGER,
        $syncColumnsSql
      )
    ''');
    await db.execute('CREATE INDEX idx_plan_exercises_plan ON plan_exercises (planId)');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        planId TEXT,
        name TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        totalVolume REAL NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        $syncColumnsSql
      )
    ''');
    await db.execute('CREATE INDEX idx_workouts_started ON workouts (startedAt)');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id TEXT PRIMARY KEY,
        workoutId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        exerciseName TEXT NOT NULL,
        position INTEGER NOT NULL,
        $syncColumnsSql
      )
    ''');
    await db.execute('CREATE INDEX idx_workout_exercises_workout ON workout_exercises (workoutId)');
    await db.execute('CREATE INDEX idx_workout_exercises_exercise ON workout_exercises (exerciseId)');

    await db.execute('''
      CREATE TABLE workout_sets (
        id TEXT PRIMARY KEY,
        workoutExerciseId TEXT NOT NULL,
        position INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        $syncColumnsSql
      )
    ''');
    await db.execute('CREATE INDEX idx_workout_sets_entry ON workout_sets (workoutExerciseId)');

    await db.execute('''
      CREATE TABLE schedules (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        planId TEXT NOT NULL,
        reminderMinutes INTEGER,
        $syncColumnsSql
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_schedules_date ON schedules (date) WHERE deletedAt IS NULL');

    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        units TEXT NOT NULL DEFAULT 'kg',
        experience TEXT,
        birthYear INTEGER,
        heightCm REAL,
        workoutsPerWeek INTEGER NOT NULL DEFAULT 3,
        primaryGoal TEXT,
        onboardedAt INTEGER,
        $syncColumnsSql
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        exerciseId TEXT,
        targetValue REAL NOT NULL,
        startValue REAL,
        deadline TEXT,
        achievedAt INTEGER,
        $syncColumnsSql
      )
    ''');

    await db.execute('''
      CREATE TABLE body_weights (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        weightKg REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        $syncColumnsSql
      )
    ''');
    await db.execute('CREATE INDEX idx_body_weights_date ON body_weights (date)');

    // Local only, never synced: the in-progress workout, so it survives the
    // app being killed.
    await db.execute('''
      CREATE TABLE active_workout (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        data TEXT NOT NULL
      )
    ''');
  }

  /// Inserts the built-in exercises and plans if they aren't there yet.
  /// Seeded rows have updatedAt 0 and aren't dirty, so they never upload
  /// unless the user edits them.
  Future<void> _seedBuiltins(DatabaseExecutor db) async {
    for (final e in seedExercises) {
      await db.insert(
        'exercises',
        {
          'id': e.id,
          'name': e.name,
          'muscleGroup': e.muscleGroup,
          'notes': e.notes,
          'isCustom': 0,
          'updatedAt': 0,
          'dirty': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final plan in seedPlans) {
      final inserted = await db.insert(
        'plans',
        {'id': plan.id, 'name': plan.name, 'updatedAt': 0, 'dirty': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted == 0) continue; // already seeded; keep the user's edits

      for (var i = 0; i < plan.exerciseNames.length; i++) {
        final name = plan.exerciseNames[i];
        await db.insert('plan_exercises', {
          'id': '${plan.id}-$i',
          'planId': plan.id,
          'exerciseId': builtinExerciseId(name),
          'position': i,
          'targetSets': 3,
          'targetReps': name == 'Plank' ? null : 10,
          'updatedAt': 0,
          'dirty': 0,
        });
      }
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await _migrateLegacy(db);
    }
  }

  /// Converts any pre-v6 database (integer IDs, comma-separated plan
  /// exercises, unpadded schedule dates) to the v6 schema. Duplicate
  /// exercises left by older upgrades are merged by name.
  Future<void> _migrateLegacy(Database db) async {
    Future<bool> tableExists(String name) async => (await db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          [name],
        ))
            .isNotEmpty;

    // Tables whose names v6 reuses get moved out of the way first.
    for (final table in ['exercises', 'workouts', 'schedules']) {
      if (await tableExists(table)) {
        await db.execute('ALTER TABLE $table RENAME TO legacy_$table');
      }
    }
    // v5 created this index on the old exercises table; v6 reuses the name.
    await db.execute('DROP INDEX IF EXISTS idx_exercises_name');

    await _createSchema(db);
    await _seedBuiltins(db);

    final now = nowMs();
    final builtinIdByName = {for (final e in seedExercises) e.name: e.id};

    // Exercises: built-ins map to their fixed IDs, everything else becomes a
    // custom exercise. Same-name rows (the old duplicates) share one ID.
    final exerciseIdMap = <int, String>{};
    final exerciseIdByName = <String, String>{};
    if (await tableExists('legacy_exercises')) {
      for (final row in await db.query('legacy_exercises', orderBy: 'id')) {
        final name = row['name'] as String;
        var id = builtinIdByName[name] ?? exerciseIdByName[name];
        if (id == null) {
          id = newId();
          await db.insert('exercises', {
            'id': id,
            'name': name,
            'muscleGroup': row['muscleGroup'],
            'notes': row['notes'] ?? '',
            'isCustom': 1,
            'updatedAt': now,
            'dirty': 1,
          });
        }
        exerciseIdByName[name] = id;
        exerciseIdMap[row['id'] as int] = id;
      }
    }

    // Plans: a plan named like a built-in takes over that built-in's ID,
    // with the user's exercise list replacing the seeded one.
    final builtinPlanIdByName = {for (final p in seedPlans) p.name: p.id};
    final planIdMap = <int, String>{};
    if (await tableExists('workout_plans')) {
      final claimed = <String>{};
      for (final row in await db.query('workout_plans', orderBy: 'id')) {
        final name = row['name'] as String;
        final builtinId = builtinPlanIdByName[name];
        final String planId;
        if (builtinId != null && claimed.add(builtinId)) {
          planId = builtinId;
          await db.delete('plan_exercises', where: 'planId = ?', whereArgs: [planId]);
          await db.update('plans', {'updatedAt': now, 'dirty': 1},
              where: 'id = ?', whereArgs: [planId]);
        } else {
          planId = newId();
          await db.insert('plans', {'id': planId, 'name': name, 'updatedAt': now, 'dirty': 1});
        }
        planIdMap[row['id'] as int] = planId;

        final oldIds = (row['exerciseIds'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse);
        final newIds = <String>[];
        for (final oldId in oldIds) {
          final id = exerciseIdMap[oldId];
          if (id != null && !newIds.contains(id)) newIds.add(id);
        }
        for (var i = 0; i < newIds.length; i++) {
          await db.insert('plan_exercises', {
            'id': newId(),
            'planId': planId,
            'exerciseId': newIds[i],
            'position': i,
            'targetSets': 3,
            'targetReps': 10,
            'updatedAt': now,
            'dirty': 1,
          });
        }
      }
    }

    // Workouts with their exercises and completed sets. Old workouts stored
    // the finish time and whole minutes, and no name.
    if (await tableExists('legacy_workouts')) {
      final hasEntries = await tableExists('exercise_entries');
      final hasSets = await tableExists('set_entries');
      for (final w in await db.query('legacy_workouts', orderBy: 'id')) {
        final workoutId = newId();
        final durationSeconds = (w['duration'] as int) * 60;
        final finishedAt = DateTime.parse(w['date'] as String);
        await db.insert('workouts', {
          'id': workoutId,
          'planId': null,
          'name': 'Workout',
          'startedAt': finishedAt.millisecondsSinceEpoch - durationSeconds * 1000,
          'durationSeconds': durationSeconds,
          'totalVolume': (w['totalVolume'] as num).toDouble(),
          'updatedAt': now,
          'dirty': 1,
        });
        if (!hasEntries) continue;

        final entries = await db.query('exercise_entries',
            where: 'workoutId = ?', whereArgs: [w['id']], orderBy: 'id');
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          final entryId = newId();
          await db.insert('workout_exercises', {
            'id': entryId,
            'workoutId': workoutId,
            'exerciseId': exerciseIdMap[entry['exerciseId']] ??
                exerciseIdByName[entry['exerciseName']] ??
                'missing-${entry['exerciseId']}',
            'exerciseName': entry['exerciseName'],
            'position': i,
            'updatedAt': now,
            'dirty': 1,
          });
          if (!hasSets) continue;

          final sets = await db.query('set_entries',
              where: 'exerciseEntryId = ? AND completed = 1',
              whereArgs: [entry['id']],
              orderBy: 'id');
          for (var j = 0; j < sets.length; j++) {
            await db.insert('workout_sets', {
              'id': newId(),
              'workoutExerciseId': entryId,
              'position': j,
              'weight': (sets[j]['weight'] as num).toDouble(),
              'reps': sets[j]['reps'],
              'updatedAt': now,
              'dirty': 1,
            });
          }
        }
      }
    }

    // Schedules: pad the date keys and point at the new plan IDs.
    if (await tableExists('legacy_schedules')) {
      for (final s in await db.query('legacy_schedules', orderBy: 'id')) {
        final planId = planIdMap[s['planId']];
        if (planId == null) continue;
        final date = dateKey(parseDateKey(s['date'] as String));
        await db.delete('schedules', where: 'date = ?', whereArgs: [date]);
        await db.insert('schedules', {
          'id': newId(),
          'date': date,
          'planId': planId,
          'updatedAt': now,
          'dirty': 1,
        });
      }
    }

    for (final table in [
      'set_entries',
      'exercise_entries',
      'legacy_schedules',
      'workout_plans',
      'legacy_workouts',
      'legacy_exercises',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }
}
