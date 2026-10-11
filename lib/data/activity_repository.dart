import 'package:sqflite/sqflite.dart';
import '../models/activity.dart';
import '../services/database_service.dart';
import 'sync_columns.dart';

class ActivityRepository {
  static final ActivityRepository instance = ActivityRepository._();
  ActivityRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// Activities started on or after [since], newest first.
  Future<List<Activity>> getActivities({required DateTime since}) async {
    final db = await _db;
    final rows = await db.query('activities',
        where: 'startedAt >= ? AND $notDeleted',
        whereArgs: [since.millisecondsSinceEpoch],
        orderBy: 'startedAt DESC');
    return rows.map(Activity.fromMap).toList();
  }

  /// Adds or updates [activity], keeping its id.
  Future<void> save(Activity activity) async {
    final db = await _db;
    final existing = await db.query('activities', columns: ['id'], where: 'id = ?', whereArgs: [activity.id]);
    if (existing.isEmpty) {
      await db.insert('activities', touched(activity.toMap()));
    } else {
      await db.update('activities', touched(activity.toMap()), where: 'id = ?', whereArgs: [activity.id]);
    }
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update('activities', softDeleted(), where: 'id = ?', whereArgs: [id]);
  }

  /// Health records already imported (including deleted ones, so a
  /// deleted import isn't brought back).
  Future<Set<String>> importedExternalIds() async {
    final db = await _db;
    final rows = await db.query('activities', columns: ['externalId'], where: 'externalId IS NOT NULL');
    return {for (final r in rows) r['externalId'] as String};
  }

  /// Calories burned on [day]: activities plus gym workouts.
  Future<double> burnedOn(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(kcal), 0) FROM activities
          WHERE startedAt >= ?1 AND startedAt < ?2 AND deletedAt IS NULL) +
        (SELECT COALESCE(SUM(kcal), 0) FROM workouts
          WHERE startedAt >= ?1 AND startedAt < ?2 AND deletedAt IS NULL) AS total
    ''', [start, end]);
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }
}
