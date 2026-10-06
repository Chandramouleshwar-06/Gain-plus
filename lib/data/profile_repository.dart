import 'package:sqflite/sqflite.dart';
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
}
