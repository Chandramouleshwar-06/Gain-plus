import 'package:cloud_firestore/cloud_firestore.dart';
import 'remote_store.dart';

/// Cloud Firestore backend: `users/{uid}/{table}/{id}`. Each write is
/// stamped with the server time in `syncedAt`.
class FirestoreRemoteStore implements RemoteStore {
  final FirebaseFirestore _db;

  static const _timeout = Duration(seconds: 30);

  FirestoreRemoteStore([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid, String table) =>
      _db.collection('users').doc(uid).collection(table);

  @override
  Future<void> upsert(String uid, String table, List<Map<String, Object?>> rows) async {
    final collection = _collection(uid, table);
    for (var i = 0; i < rows.length; i += 400) {
      final batch = _db.batch();
      for (final row in rows.skip(i).take(400)) {
        batch.set(collection.doc(row['id'] as String), {...row, 'syncedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit().timeout(_timeout);
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(String uid, String table, int syncedAfter) async {
    final snapshot = await _collection(uid, table)
        .where('syncedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(syncedAfter))
        .orderBy('syncedAt')
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return [
      for (final doc in snapshot.docs)
        {
          ...doc.data(),
          'syncedAt': (doc.data()['syncedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? syncedAfter,
        },
    ];
  }
}
