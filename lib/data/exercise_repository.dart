import 'package:sqflite/sqflite.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import 'sync_columns.dart';

class ExerciseRepository {
  static final ExerciseRepository instance = ExerciseRepository._();
  ExerciseRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  Future<List<Exercise>> getAll() async {
    final db = await _db;
    final rows = await db.query('exercises', where: notDeleted, orderBy: 'name COLLATE NOCASE');
    return rows.map(Exercise.fromMap).toList();
  }

  /// Adds a custom exercise. Returns null if one with the same name exists.
  Future<Exercise?> addCustom({
    required String name,
    required String muscleGroup,
    String notes = '',
  }) async {
    final exercise = Exercise(
      id: newId(),
      name: name,
      muscleGroup: muscleGroup,
      notes: notes,
      isCustom: true,
    );
    final db = await _db;
    try {
      await db.insert('exercises', touched(exercise.toMap()));
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return null;
      rethrow;
    }
    return exercise;
  }
}
