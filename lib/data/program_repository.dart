import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../utils/date_keys.dart';
import 'sync_columns.dart';

/// A program you built: workouts done in order on chosen weekdays.
class CustomProgram {
  final String id;
  final String name;

  /// Training weekdays, 1 = Monday ... 7 = Sunday, ascending.
  final List<int> weekdays;
  final int weeks;

  /// Plan IDs in the order they rotate.
  final List<String> planIds;

  /// First day of the current run, or null when not started.
  final DateTime? startedOn;

  /// Reminder time (minutes after midnight) used when scheduling.
  final int? reminderMinutes;

  CustomProgram({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.weeks,
    required this.planIds,
    this.startedOn,
    this.reminderMinutes,
  });

  bool get isActive => startedOn != null;

  factory CustomProgram.fromMap(Map<String, Object?> map, List<String> planIds) {
    final started = map['startedOn'] as String?;
    return CustomProgram(
      id: map['id'] as String,
      name: map['name'] as String,
      weekdays: (map['weekdays'] as String).split(',').where((s) => s.isNotEmpty).map(int.parse).toList(),
      weeks: map['weeks'] as int,
      planIds: planIds,
      startedOn: started == null ? null : parseDateKey(started),
      reminderMinutes: map['reminderMinutes'] as int?,
    );
  }
}

class ProgramRepository {
  static final ProgramRepository instance = ProgramRepository._();
  ProgramRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  Future<List<CustomProgram>> getAll() async {
    final db = await _db;
    final rows = await db.query('programs', where: notDeleted, orderBy: 'name COLLATE NOCASE');
    final workoutRows = await db.query('program_workouts', where: notDeleted, orderBy: 'position');
    final plansByProgram = <String, List<String>>{};
    for (final w in workoutRows) {
      plansByProgram.putIfAbsent(w['programId'] as String, () => []).add(w['planId'] as String);
    }
    return rows.map((r) => CustomProgram.fromMap(r, plansByProgram[r['id']] ?? [])).toList();
  }

  /// Creates or updates a program, replacing its workout list.
  Future<String> save({
    String? id,
    required String name,
    required List<int> weekdays,
    required int weeks,
    required List<String> planIds,
    int? reminderMinutes,
  }) async {
    final programId = id ?? newId();
    final db = await _db;
    await db.transaction((txn) async {
      final values = {
        'name': name,
        'weekdays': ([...weekdays]..sort()).join(','),
        'weeks': weeks,
        'reminderMinutes': reminderMinutes,
      };
      if (id == null) {
        await txn.insert('programs', touched({'id': programId, ...values}));
      } else {
        await txn.update('programs', touched(values), where: 'id = ?', whereArgs: [id]);
        await txn.update('program_workouts', softDeleted(),
            where: 'programId = ? AND $notDeleted', whereArgs: [id]);
      }
      for (var i = 0; i < planIds.length; i++) {
        await txn.insert(
          'program_workouts',
          touched({'id': newId(), 'programId': programId, 'planId': planIds[i], 'position': i}),
        );
      }
    });
    return programId;
  }

  Future<void> setStartedOn(String id, DateTime? startedOn, {int? reminderMinutes}) async {
    final db = await _db;
    await db.update(
        'programs',
        touched({
          'startedOn': startedOn == null ? null : dateKey(startedOn),
          'reminderMinutes': ?reminderMinutes,
        }),
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('program_workouts', softDeleted(), where: 'programId = ? AND $notDeleted', whereArgs: [id]);
      await txn.update('programs', softDeleted(), where: 'id = ?', whereArgs: [id]);
    });
  }
}
