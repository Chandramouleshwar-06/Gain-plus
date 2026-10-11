import 'package:flutter/material.dart';
import '../../data/builtin_foods.dart';
import '../../data/food_repository.dart';
import '../../models/food.dart';

/// Food log for one day at a time, plus saved and recent foods.
class NutritionProvider extends ChangeNotifier {
  DateTime day = _today();
  List<FoodLog> logs = [];
  List<Food> savedFoods = [];
  List<Food> recentFoods = [];

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isToday => day == _today();
  Macros get totals => Macros.of(logs);
  Macros totalsFor(String meal) => Macros.of(logs.where((l) => l.meal == meal));

  Food? foodById(String? id) {
    if (id == null) return null;
    return builtinFoods.where((f) => f.id == id).firstOrNull ?? savedFoods.where((f) => f.id == id).firstOrNull;
  }

  Future<void> load() async {
    final repo = FoodRepository.instance;
    logs = await repo.getLogs(day);
    savedFoods = await repo.getSavedFoods();
    recentFoods = [
      for (final (id, _) in await repo.recentFoodRefs()) ?foodById(id),
    ];
    notifyListeners();
  }

  Future<void> setDay(DateTime newDay) async {
    day = DateTime(newDay.year, newDay.month, newDay.day);
    await load();
  }

  /// Logs [food]; foods from online search are saved first so they work offline.
  Future<void> log(Food food, {required String meal, required double servings}) async {
    if (food.source == 'off' || food.source == 'custom') await FoodRepository.instance.saveFood(food);
    await FoodRepository.instance.log(food, day: day, meal: meal, servings: servings);
    await load();
  }

  Future<void> deleteLog(String id) async {
    await FoodRepository.instance.deleteLog(id);
    await load();
  }
}

/// Which meal it probably is right now.
String mealForNow([DateTime? at]) {
  final h = (at ?? DateTime.now()).hour;
  if (h < 11) return 'breakfast';
  if (h < 16) return 'lunch';
  if (h >= 19) return 'dinner';
  return 'snacks';
}
