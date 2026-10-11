import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/sync_columns.dart';
import '../services/database_service.dart';
import 'remote_store.dart';

/// Synced tables, parents before children.
const syncedTables = [
  'exercises',
  'plans',
  'plan_exercises',
  'programs',
  'program_workouts',
  'workouts',
  'workout_exercises',
  'workout_sets',
  'schedules',
  'profile',
  'goals',
  'body_weights',
  'foods',
  'food_logs',
  'activities',
  'body_measurements',
];

/// Columns that are only unique among live rows: two devices can each
/// create one, so on conflict the older row is retired.
const _uniqueColumns = {
  'exercises': 'name',
  'schedules': 'date',
};

class SyncResult {
  final int pushed;
  final int pulled;

  const SyncResult(this.pushed, this.pulled);

  @override
  String toString() => 'pushed $pushed, pulled $pulled';
}

/// Two-way sync between the local database and a [RemoteStore].
///
/// Pull first (newest edit wins, by `updatedAt`), then push rows still
/// marked dirty. Pulls are tracked per table by the server's `syncedAt`, so
/// a device with a wrong clock can't cause changes to be skipped.
class SyncEngine {
  final RemoteStore remote;

  SyncEngine(this.remote);

  Future<SyncResult>? _running;

  /// Runs a sync; if one is already running, returns that one.
  Future<SyncResult> sync(String uid) => _running ??= _sync(uid).whenComplete(() => _running = null);

  Future<SyncResult> _sync(String uid) async {
    final db = await DatabaseService.instance.database;
    final prefs = await SharedPreferences.getInstance();
    var pulled = 0;
    var pushed = 0;
    for (final table in syncedTables) {
      pulled += await _pull(db, prefs, uid, table);
    }
    for (final table in syncedTables) {
      pushed += await _push(db, uid, table);
    }
    return SyncResult(pushed, pulled);
  }

  Future<int> _push(Database db, String uid, String table) async {
    final rows = await db.query(table, where: 'dirty = 1');
    if (rows.isEmpty) return 0;
    for (var i = 0; i < rows.length; i += 400) {
      final batch = rows.skip(i).take(400).toList();
      await remote.upsert(uid, table, [for (final r in batch) {...r}..remove('dirty')]);
      // Only clear rows that weren't edited again while uploading.
      for (final r in batch) {
        await db.update(table, {'dirty': 0},
            where: 'id = ? AND updatedAt = ?', whereArgs: [r['id'], r['updatedAt']]);
      }
    }
    return rows.length;
  }

  Future<int> _pull(Database db, SharedPreferences prefs, String uid, String table) async {
    final cursorKey = 'sync_cursor_${uid}_$table';
    final cursor = prefs.getInt(cursorKey) ?? 0;
    final remoteRows = await remote.changedSince(uid, table, cursor);
    if (remoteRows.isEmpty) return 0;

    final columns = (await db.rawQuery('PRAGMA table_info($table)')).map((c) => c['name'] as String).toSet();
    var applied = 0;
    var newCursor = cursor;
    for (final remoteRow in remoteRows) {
      final syncedAt = remoteRow['syncedAt'] as int;
      if (syncedAt > newCursor) newCursor = syncedAt;
      // Ignore fields this version doesn't know (from a newer app version).
      final row = {
        for (final e in remoteRow.entries)
          if (columns.contains(e.key)) e.key: e.value,
        'dirty': 0,
      };
      if (await _apply(db, table, row)) applied++;
    }
    await prefs.setInt(cursorKey, newCursor);
    return applied;
  }

  /// Applies one remote row if it's newer than the local copy.
  /// Read, compare and write in one transaction, so an edit made at the same
  /// moment can't be overwritten by an older remote copy.
  Future<bool> _apply(Database db, String table, Map<String, Object?> row) =>
      db.transaction((txn) => _applyIn(txn, table, row));

  Future<bool> _applyIn(DatabaseExecutor db, String table, Map<String, Object?> row) async {
    final id = row['id'];
    final local = (await db.query(table, where: 'id = ?', whereArgs: [id])).firstOrNull;
    if (local != null && (local['updatedAt'] as int) >= (row['updatedAt'] as int)) {
      return false; // ours is as new or newer; it'll be pushed if dirty
    }

    try {
      await _write(db, table, row, exists: local != null);
      return true;
    } on DatabaseException catch (e) {
      final column = _uniqueColumns[table];
      if (!e.isUniqueConstraintError() || column == null) rethrow;
      return _resolveUnique(db, table, column, row, exists: local != null);
    }
  }

  /// Update or insert. Deliberately not ConflictAlgorithm.replace: on a
  /// unique clash that silently hard-deletes the other row.
  Future<void> _write(DatabaseExecutor db, String table, Map<String, Object?> row, {required bool exists}) async {
    if (exists) {
      await db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    } else {
      await db.insert(table, row);
    }
  }

  /// Another live row shares the unique value: the newer one stays, the
  /// older one is soft-deleted (and the deletion synced).
  Future<bool> _resolveUnique(
    DatabaseExecutor db,
    String table,
    String column,
    Map<String, Object?> row, {
    required bool exists,
  }) async {
    final other = (await db.query(table,
            where: '$column = ? AND id != ? AND $notDeleted', whereArgs: [row[column], row['id']]))
        .firstOrNull;
    if (other == null) return false;

    final String winner, loser;
    if ((other['updatedAt'] as int) < (row['updatedAt'] as int)) {
      await db.update(table, softDeleted(), where: 'id = ?', whereArgs: [other['id']]);
      await _write(db, table, row, exists: exists);
      (winner, loser) = (row['id'] as String, other['id'] as String);
    } else {
      // Keep ours; store theirs as deleted so the deletion is pushed.
      await _write(db, table, {...row, ...softDeleted()}, exists: exists);
      (winner, loser) = (other['id'] as String, row['id'] as String);
    }
    if (table == 'exercises') await _repointExercise(db, from: loser, to: winner);
    debugPrint('Sync: resolved duplicate $column in $table');
    return true;
  }

  /// Plans, workout history and goals that used a retired duplicate
  /// exercise now use the one that stayed (and the change syncs).
  Future<void> _repointExercise(DatabaseExecutor db, {required String from, required String to}) async {
    for (final table in const ['plan_exercises', 'workout_exercises', 'goals']) {
      await db.update(table, touched({'exerciseId': to}),
          where: 'exerciseId = ? AND $notDeleted', whereArgs: [from]);
    }
  }

  /// Rows waiting to be uploaded.
  static Future<int> pendingChanges() async {
    final db = await DatabaseService.instance.database;
    var total = 0;
    for (final table in syncedTables) {
      total += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE dirty = 1')) ?? 0;
    }
    return total;
  }

  /// Forgets pull positions for [uid] (after this phone's data is wiped).
  static Future<void> resetCursors(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final table in syncedTables) {
      await prefs.remove('sync_cursor_${uid}_$table');
    }
  }
}
