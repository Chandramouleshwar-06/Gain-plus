import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../utils/date_keys.dart';
import 'sync_columns.dart';

class ScheduleEntry {
  final String id;

  /// A [dateKey], e.g. `2026-10-06`.
  final String date;
  final String planId;

  /// Reminder time as minutes after midnight, or null for no reminder.
  final int? reminderMinutes;

  ScheduleEntry({
    required this.id,
    required this.date,
    required this.planId,
    this.reminderMinutes,
  });

  factory ScheduleEntry.fromMap(Map<String, Object?> map) {
    return ScheduleEntry(
      id: map['id'] as String,
      date: map['date'] as String,
      planId: map['planId'] as String,
      reminderMinutes: map['reminderMinutes'] as int?,
    );
  }
}

class ScheduleRepository {
  static final ScheduleRepository instance = ScheduleRepository._();
  ScheduleRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// Schedules keyed by [dateKey].
  Future<Map<String, ScheduleEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query('schedules', where: notDeleted);
    return {for (final row in rows) row['date'] as String: ScheduleEntry.fromMap(row)};
  }

  /// Schedules [planId] on [date], replacing whatever was scheduled that day.
  Future<void> set(DateTime date, String planId, {int? reminderMinutes}) async {
    final key = dateKey(date);
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('schedules', softDeleted(),
          where: 'date = ? AND $notDeleted', whereArgs: [key]);
      await txn.insert(
        'schedules',
        touched({
          'id': newId(),
          'date': key,
          'planId': planId,
          'reminderMinutes': reminderMinutes,
        }),
      );
    });
  }

  Future<void> clear(DateTime date) async {
    final db = await _db;
    await db.update('schedules', softDeleted(),
        where: 'date = ? AND $notDeleted', whereArgs: [dateKey(date)]);
  }
}
