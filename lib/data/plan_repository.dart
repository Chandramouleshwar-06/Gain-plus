import 'package:sqflite/sqflite.dart';
import '../models/workout_plan.dart';
import '../services/database_service.dart';
import 'sync_columns.dart';

class PlanRepository {
  static final PlanRepository instance = PlanRepository._();
  PlanRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// All plans with their exercises in order.
  Future<List<WorkoutPlan>> getAll() async {
    final db = await _db;
    final planRows = await db.query('plans', where: notDeleted, orderBy: 'name COLLATE NOCASE');
    final itemRows = await db.query('plan_exercises', where: notDeleted, orderBy: 'position');

    final itemsByPlan = <String, List<PlanExercise>>{};
    for (final row in itemRows) {
      itemsByPlan.putIfAbsent(row['planId'] as String, () => []).add(PlanExercise.fromMap(row));
    }
    return planRows
        .map((row) => WorkoutPlan.fromMap(row, itemsByPlan[row['id']] ?? []))
        .toList();
  }

  Future<String> create(String name) async {
    final id = newId();
    final db = await _db;
    await db.insert('plans', touched({'id': id, 'name': name}));
    return id;
  }

  /// Appends [exerciseId] to the end of the plan, unless it's already in it.
  Future<void> addExercise(String planId, String exerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'plan_exercises',
        where: 'planId = ? AND exerciseId = ? AND $notDeleted',
        whereArgs: [planId, exerciseId],
      );
      if (existing.isNotEmpty) return;

      final maxRow = await txn.rawQuery(
        'SELECT MAX(position) AS maxPos FROM plan_exercises WHERE planId = ? AND $notDeleted',
        [planId],
      );
      final nextPosition = ((maxRow.first['maxPos'] as int?) ?? -1) + 1;
      await txn.insert(
        'plan_exercises',
        touched({
          'id': newId(),
          'planId': planId,
          'exerciseId': exerciseId,
          'position': nextPosition,
          'targetSets': 3,
          'targetReps': 10,
        }),
      );
      await _touchPlan(txn, planId);
    });
  }

  Future<void> removeExercise(String planId, String exerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'plan_exercises',
        softDeleted(),
        where: 'planId = ? AND exerciseId = ? AND $notDeleted',
        whereArgs: [planId, exerciseId],
      );
      await _touchPlan(txn, planId);
    });
  }

  Future<void> rename(String planId, String name) async {
    final db = await _db;
    await db.update('plans', touched({'name': name}), where: 'id = ?', whereArgs: [planId]);
  }

  /// Saves a new exercise order. [itemIds] are plan_exercises IDs, first to last.
  Future<void> reorder(String planId, List<String> itemIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < itemIds.length; i++) {
        await txn.update('plan_exercises', touched({'position': i}),
            where: 'id = ? AND planId = ?', whereArgs: [itemIds[i], planId]);
      }
      await _touchPlan(txn, planId);
    });
  }

  /// Deletes a plan with its exercises and schedules. Returns the date keys
  /// of the schedules removed, so their reminders can be cancelled.
  Future<List<String>> delete(String planId) async {
    final db = await _db;
    return db.transaction((txn) async {
      final schedules = await txn.query('schedules',
          columns: ['date'], where: 'planId = ? AND $notDeleted', whereArgs: [planId]);
      await txn.update('schedules', softDeleted(), where: 'planId = ? AND $notDeleted', whereArgs: [planId]);
      await txn.update('plan_exercises', softDeleted(),
          where: 'planId = ? AND $notDeleted', whereArgs: [planId]);
      await txn.update('plans', softDeleted(), where: 'id = ?', whereArgs: [planId]);
      return schedules.map((s) => s['date'] as String).toList();
    });
  }

  Future<void> _touchPlan(DatabaseExecutor db, String planId) =>
      db.update('plans', touched({}), where: 'id = ?', whereArgs: [planId]);
}
