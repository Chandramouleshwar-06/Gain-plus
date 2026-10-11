import 'package:sqflite/sqflite.dart';
import '../models/body.dart';
import '../models/profile.dart';
import '../services/database_service.dart';
import '../utils/date_keys.dart';
import 'sync_columns.dart';

/// Profile, goals and body weight log.
class ProfileRepository {
  static final ProfileRepository instance = ProfileRepository._();
  ProfileRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// The saved profile, or null before onboarding.
  Future<Profile?> getProfile() async {
    final db = await _db;
    final rows = await db.query('profile',
        where: 'id = ? AND $notDeleted', whereArgs: [Profile.singletonId]);
    return rows.isEmpty ? null : Profile.fromMap(rows.first);
  }

  Future<void> saveProfile(Profile profile) async {
    final db = await _db;
    await db.insert('profile', touched(profile.toMap()),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Goal>> getGoals() async {
    final db = await _db;
    final rows = await db.query('goals', where: notDeleted, orderBy: 'updatedAt');
    return rows.map(Goal.fromMap).toList();
  }

  /// Inserts or updates [goal].
  Future<void> saveGoal(Goal goal) async {
    final db = await _db;
    await db.insert('goals', touched(goal.toMap()), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteGoal(String id) async {
    final db = await _db;
    await db.update('goals', softDeleted(), where: 'id = ?', whereArgs: [id]);
  }

  /// Body weight entries, oldest first.
  Future<List<BodyWeightEntry>> getBodyWeights() async {
    final db = await _db;
    final rows = await db.query('body_weights', where: notDeleted, orderBy: 'date');
    return rows.map(BodyWeightEntry.fromMap).toList();
  }

  Future<void> addBodyWeight(DateTime date, double weightKg, {String source = 'manual'}) async {
    final db = await _db;
    await db.insert(
      'body_weights',
      touched({'id': newId(), 'date': dateKey(date), 'weightKg': weightKg, 'source': source}),
    );
  }

  Future<void> deleteBodyWeight(String id) async {
    final db = await _db;
    await db.update('body_weights', softDeleted(), where: 'id = ?', whereArgs: [id]);
  }

  /// Body measurements, oldest first.
  Future<List<BodyMeasurement>> getMeasurements() async {
    final db = await _db;
    final rows = await db.query('body_measurements', where: notDeleted, orderBy: 'date, updatedAt');
    return [
      for (final r in rows)
        BodyMeasurement(
          id: r['id'] as String,
          date: parseDateKey(r['date'] as String),
          site: r['site'] as String,
          value: (r['value'] as num).toDouble(),
        ),
    ];
  }

  /// Saves [values] (site code -> cm or %) for [date]. A site measured
  /// again on the same day is updated rather than added twice.
  Future<void> saveMeasurements(DateTime date, Map<String, double> values) async {
    final db = await _db;
    final day = dateKey(date);
    await db.transaction((txn) async {
      for (final MapEntry(key: site, :value) in values.entries) {
        final existing = await txn.query('body_measurements',
            columns: ['id'], where: 'date = ? AND site = ? AND $notDeleted', whereArgs: [day, site]);
        if (existing.isEmpty) {
          await txn.insert('body_measurements', touched({'id': newId(), 'date': day, 'site': site, 'value': value}));
        } else {
          await txn.update('body_measurements', touched({'value': value}),
              where: 'id = ?', whereArgs: [existing.first['id']]);
        }
      }
    });
  }

  Future<void> deleteMeasurement(String id) async {
    final db = await _db;
    await db.update('body_measurements', softDeleted(), where: 'id = ?', whereArgs: [id]);
  }
}
