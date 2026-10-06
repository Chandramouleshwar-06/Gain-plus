import 'package:uuid/uuid.dart';

/// Every table that syncs to the cloud carries these columns:
/// - `updatedAt`: last change, ms since epoch (newest edit wins on sync)
/// - `deletedAt`: set instead of deleting the row, so the delete can sync
/// - `dirty`: 1 when the row changed locally and hasn't been uploaded yet
const syncColumnsSql =
    'updatedAt INTEGER NOT NULL, deletedAt INTEGER, dirty INTEGER NOT NULL DEFAULT 1';

/// WHERE clause for rows that haven't been deleted.
const notDeleted = 'deletedAt IS NULL';

const _uuid = Uuid();

String newId() => _uuid.v4();

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// [values] marked as a local change that needs uploading.
Map<String, Object?> touched(Map<String, Object?> values) =>
    {...values, 'updatedAt': nowMs(), 'dirty': 1};

/// Column values that soft-delete a row.
Map<String, Object?> softDeleted() {
  final now = nowMs();
  return {'deletedAt': now, 'updatedAt': now, 'dirty': 1};
}
