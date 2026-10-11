/// The cloud side of sync. Rows are stored per user and table, keyed by id.
abstract class RemoteStore {
  /// Writes [rows] (each with an 'id'). The store stamps each with its own
  /// increasing `syncedAt` time, used by [changedSince].
  Future<void> upsert(String uid, String table, List<Map<String, Object?>> rows);

  /// Rows written after [syncedAfter] (server time, ms), oldest first, each
  /// including its `syncedAt`.
  Future<List<Map<String, Object?>>> changedSince(String uid, String table, int syncedAfter);
}

/// In-memory store for tests and for running without a backend.
class MemoryRemoteStore implements RemoteStore {
  final Map<String, Map<String, Map<String, Object?>>> _tables = {};
  int _clock = 0;

  @override
  Future<void> upsert(String uid, String table, List<Map<String, Object?>> rows) async {
    final store = _tables.putIfAbsent('$uid/$table', () => {});
    for (final row in rows) {
      store[row['id'] as String] = {...row, 'syncedAt': ++_clock};
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(String uid, String table, int syncedAfter) async {
    final rows = (_tables['$uid/$table'] ?? {}).values.where((r) => (r['syncedAt'] as int) > syncedAfter).toList()
      ..sort((a, b) => (a['syncedAt'] as int).compareTo(b['syncedAt'] as int));
    return rows.map((r) => {...r}).toList();
  }

  /// Everything stored for [table], for test assertions.
  List<Map<String, Object?>> rows(String uid, String table) => (_tables['$uid/$table'] ?? {}).values.toList();
}
