import 'package:sqflite/sqflite.dart';
import '../models/food.dart';
import '../services/database_service.dart';
import '../utils/date_keys.dart';
import 'sync_columns.dart';

class FoodRepository {
  static final FoodRepository instance = FoodRepository._();
  FoodRepository._();

  Future<Database> get _db => DatabaseService.instance.database;

  /// Foods you created or logged from online search.
  Future<List<Food>> getSavedFoods() async {
    final db = await _db;
    final rows = await db.query('foods', where: notDeleted, orderBy: 'name COLLATE NOCASE');
    return rows.map(Food.fromMap).toList();
  }

  /// Saves a food (keeping its id), so it can be found and logged offline.
  Future<void> saveFood(Food food) async {
    final db = await _db;
    final existing = await db.query('foods', columns: ['id'], where: 'id = ?', whereArgs: [food.id]);
    if (existing.isEmpty) {
      await db.insert('foods', touched(food.toMap()));
    } else {
      await db.update('foods', touched(food.toMap()), where: 'id = ?', whereArgs: [food.id]);
    }
  }

  Future<List<FoodLog>> getLogs(DateTime day) async {
    final db = await _db;
    final rows = await db.query('food_logs',
        where: 'date = ? AND $notDeleted', whereArgs: [dateKey(day)], orderBy: 'updatedAt');
    return rows.map(_logFromMap).toList();
  }

  /// Logs [servings] of [food] to [meal] on [day].
  Future<void> log(Food food, {required DateTime day, required String meal, required double servings}) async {
    final db = await _db;
    await db.insert(
      'food_logs',
      touched({
        'id': newId(),
        'date': dateKey(day),
        'meal': meal,
        'foodId': food.id,
        'name': food.name,
        'servings': servings,
        'kcal': food.kcal * servings,
        'protein': food.protein * servings,
        'carbs': food.carbs * servings,
        'fat': food.fat * servings,
      }),
    );
  }

  Future<void> deleteLog(String id) async {
    final db = await _db;
    await db.update('food_logs', softDeleted(), where: 'id = ?', whereArgs: [id]);
  }

  /// Distinct foods logged recently, most recent first: (foodId, name).
  Future<List<(String?, String)>> recentFoodRefs({int limit = 15}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT foodId, name, MAX(updatedAt) AS last FROM food_logs
      WHERE deletedAt IS NULL GROUP BY name ORDER BY last DESC LIMIT ?
    ''', [limit]);
    return rows.map((r) => (r['foodId'] as String?, r['name'] as String)).toList();
  }

  FoodLog _logFromMap(Map<String, Object?> map) => FoodLog(
        id: map['id'] as String,
        date: parseDateKey(map['date'] as String),
        meal: map['meal'] as String,
        foodId: map['foodId'] as String?,
        name: map['name'] as String,
        servings: (map['servings'] as num).toDouble(),
        kcal: (map['kcal'] as num).toDouble(),
        protein: (map['protein'] as num).toDouble(),
        carbs: (map['carbs'] as num).toDouble(),
        fat: (map['fat'] as num).toDouble(),
      );
}
