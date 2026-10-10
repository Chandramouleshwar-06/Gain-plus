import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import '../services/database_service.dart';
import 'sync_columns.dart';

/// A completed set joined with its exercise, used for personal records.
class SetRecord {
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;

  SetRecord(this.exerciseId, this.exerciseName, this.weight, this.reps);
}

class WorkoutStats {
  final int count;
  final double totalVolume;

  WorkoutStats(this.count, this.totalVolume);
}

class WorkoutRepository {
  static final WorkoutRepository instance = WorkoutRepository._();
  WorkoutRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// Saves a finished workout with its exercises and sets in one
  /// transaction. IDs on [workout] and its children are used as given.
  Future<void> save(Workout workout) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('workouts', touched(workout.toMap()));
      for (final entry in workout.exercises) {
        await txn.insert(
          'workout_exercises',
          touched({
            'id': entry.id,
            'workoutId': workout.id,
            'exerciseId': entry.exerciseId,
            'exerciseName': entry.exerciseName,
            'position': entry.position,
          }),
        );
        for (final set in entry.sets) {
          await txn.insert(
            'workout_sets',
            touched({
              'id': set.id,
              'workoutExerciseId': entry.id,
              'position': set.position,
              'weight': set.weight,
              'reps': set.reps,
            }),
          );
        }
      }
    });
  }

  /// Deletes a workout with its exercises and sets.
  Future<void> delete(String workoutId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final entries = await txn.query('workout_exercises',
          columns: ['id'], where: 'workoutId = ? AND $notDeleted', whereArgs: [workoutId]);
      for (final entry in entries) {
        await txn.update('workout_sets', softDeleted(),
            where: 'workoutExerciseId = ? AND $notDeleted', whereArgs: [entry['id']]);
      }
      await txn.update('workout_exercises', softDeleted(),
          where: 'workoutId = ? AND $notDeleted', whereArgs: [workoutId]);
      await txn.update('workouts', softDeleted(), where: 'id = ?', whereArgs: [workoutId]);
    });
  }

  /// Workouts newest first, without their exercises.
  Future<List<Workout>> getRecent({int? limit}) async {
    final db = await _db;
    final rows = await db.query('workouts', where: notDeleted, orderBy: 'startedAt DESC', limit: limit);
    return rows.map((row) => Workout.fromMap(row)).toList();
  }

  /// Start times of every workout, for streaks and weekly goals.
  Future<List<DateTime>> getWorkoutDates() async {
    final db = await _db;
    final rows = await db.query('workouts', columns: ['startedAt'], where: notDeleted);
    return rows.map((r) => DateTime.fromMillisecondsSinceEpoch(r['startedAt'] as int)).toList();
  }

  Future<WorkoutStats> getStats() async {
    final db = await _db;
    final row = (await db.rawQuery(
      'SELECT COUNT(*) AS count, COALESCE(SUM(totalVolume), 0) AS volume FROM workouts WHERE $notDeleted',
    ))
        .first;
    return WorkoutStats(row['count'] as int, (row['volume'] as num).toDouble());
  }

  /// One workout with its exercises and sets, or null if it doesn't exist.
  Future<Workout?> getWithDetails(String id) async {
    final db = await _db;
    final rows = await db.query('workouts', where: 'id = ? AND $notDeleted', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final entryRows = await db.query('workout_exercises',
        where: 'workoutId = ? AND $notDeleted', whereArgs: [id], orderBy: 'position');
    final entries = <ExerciseEntry>[];
    for (final entryRow in entryRows) {
      final setRows = await db.query('workout_sets',
          where: 'workoutExerciseId = ? AND $notDeleted',
          whereArgs: [entryRow['id']],
          orderBy: 'position');
      entries.add(ExerciseEntry.fromMap(entryRow, setRows.map(SetEntry.fromMap).toList()));
    }
    return Workout.fromMap(rows.first, entries);
  }

  /// The sets done for [exerciseId] in the most recent workout that had it,
  /// or an empty list if it was never done.
  Future<List<SetEntry>> getLastSets(String exerciseId) async {
    final db = await _db;
    final entries = await db.rawQuery('''
      SELECT we.id FROM workout_exercises we
      JOIN workouts w ON w.id = we.workoutId
      WHERE we.exerciseId = ? AND we.deletedAt IS NULL AND w.deletedAt IS NULL
      ORDER BY w.startedAt DESC
      LIMIT 1
    ''', [exerciseId]);
    if (entries.isEmpty) return [];
    final rows = await db.query('workout_sets',
        where: 'workoutExerciseId = ? AND $notDeleted', whereArgs: [entries.first['id']], orderBy: 'position');
    return rows.map(SetEntry.fromMap).toList();
  }

  /// Every completed set with its exercise, in one query.
  Future<List<SetRecord>> getAllSets() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT we.exerciseId, we.exerciseName, s.weight, s.reps
      FROM workout_sets s
      JOIN workout_exercises we ON we.id = s.workoutExerciseId
      JOIN workouts w ON w.id = we.workoutId
      WHERE s.deletedAt IS NULL AND we.deletedAt IS NULL AND w.deletedAt IS NULL
    ''');
    return rows
        .map((r) => SetRecord(
              r['exerciseId'] as String,
              r['exerciseName'] as String,
              (r['weight'] as num).toDouble(),
              r['reps'] as int,
            ))
        .toList();
  }
}

/// One workout's sets for a single exercise.
class ExerciseSession {
  final DateTime date;
  final List<SetEntry> sets;

  ExerciseSession(this.date, this.sets);
}

extension ExerciseHistory on WorkoutRepository {
  /// Every session of [exerciseId], oldest first.
  Future<List<ExerciseSession>> getExerciseHistory(String exerciseId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT we.id AS entryId, w.startedAt, s.id, s.position, s.weight, s.reps
      FROM workout_sets s
      JOIN workout_exercises we ON we.id = s.workoutExerciseId
      JOIN workouts w ON w.id = we.workoutId
      WHERE we.exerciseId = ? AND s.deletedAt IS NULL AND we.deletedAt IS NULL AND w.deletedAt IS NULL
      ORDER BY w.startedAt, s.position
    ''', [exerciseId]);

    final sessions = <String, ExerciseSession>{};
    for (final r in rows) {
      sessions
          .putIfAbsent(
            r['entryId'] as String,
            () => ExerciseSession(DateTime.fromMillisecondsSinceEpoch(r['startedAt'] as int), []),
          )
          .sets
          .add(SetEntry.fromMap(r));
    }
    return sessions.values.toList();
  }

  /// (start time, volume) of every workout.
  Future<List<(DateTime, double)>> getVolumes() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('workouts', columns: ['startedAt', 'totalVolume'], where: notDeleted);
    return rows
        .map((r) => (DateTime.fromMillisecondsSinceEpoch(r['startedAt'] as int), (r['totalVolume'] as num).toDouble()))
        .toList();
  }
}

/// Stores the in-progress workout locally so it survives the app being
/// killed. Not synced.
class ActiveWorkoutStore {
  static final ActiveWorkoutStore instance = ActiveWorkoutStore._();
  ActiveWorkoutStore._();

  Future<Database> get _db => DatabaseService.instance.database;

  Future<String?> load() async {
    final db = await _db;
    final rows = await db.query('active_workout', where: 'id = 1');
    return rows.isEmpty ? null : rows.first['data'] as String;
  }

  Future<void> save(String data) async {
    final db = await _db;
    await db.insert('active_workout', {'id': 1, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete('active_workout');
  }
}
