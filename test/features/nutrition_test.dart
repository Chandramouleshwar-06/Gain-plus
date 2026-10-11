import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gain_plus/data/builtin_foods.dart';
import 'package:gain_plus/features/nutrition/nutrition_provider.dart';
import 'package:gain_plus/features/nutrition/targets.dart';
import 'package:gain_plus/models/food.dart';
import 'package:gain_plus/services/open_food_facts.dart';

import '../helpers/test_db.dart';

void main() {
  test('targets: Mifflin-St Jeor x activity, adjusted for the goal', () {
    // 80 kg, 180 cm, 30 years, male: BMR = 800 + 1125 - 150 + 5 = 1780.
    final maintain = calculateTargets(
      weightKg: 80, heightCm: 180, birthYear: 1996, sex: 'male',
      activityLevel: 'moderate', goal: 'general_fitness', currentYear: 2026,
    )!;
    expect(maintain.kcal, 2760, reason: '1780 x 1.55 = 2759 -> rounded to 10');
    expect(maintain.protein, 112, reason: '1.4 g/kg');

    final cut = calculateTargets(
      weightKg: 80, heightCm: 180, birthYear: 1996, sex: 'male',
      activityLevel: 'moderate', goal: 'lose_fat', currentYear: 2026,
    )!;
    expect(cut.kcal, 2210, reason: '20% under maintenance');
    expect(cut.protein, 160, reason: '2 g/kg while cutting');
    expect(cut.protein * 4 + cut.carbs * 4 + cut.fat * 9, closeTo(cut.kcal, 10));

    final female = calculateTargets(
      weightKg: 60, heightCm: 165, birthYear: 1996, sex: 'female',
      activityLevel: 'sedentary', goal: 'general_fitness', currentYear: 2026,
    )!;
    // BMR = 600 + 1031.25 - 150 - 161 = 1320.25 -> x1.2 = 1584.3
    expect(female.kcal, 1580);
  });

  test('targets need every detail', () {
    expect(
      calculateTargets(weightKg: 80, heightCm: null, birthYear: 1996, sex: 'male',
          activityLevel: 'moderate', goal: null, currentYear: 2026),
      isNull,
    );
    expect(missingForTargets(weightKg: 80, birthYear: 1996), ['height', 'sex', 'activity level']);
  });

  test('Open Food Facts products: per serving when given, else per 100 g', () {
    final perServing = OpenFoodFacts.parseProduct({
      'code': '123',
      'product_name': 'Protein Bar',
      'brands': 'Brand A, Brand B',
      'serving_size': '1 bar (60 g)',
      'serving_quantity': 60,
      'nutriments': {'energy-kcal_100g': 400, 'proteins_100g': 33.3, 'carbohydrates_100g': 40, 'fat_100g': 10},
    })!;
    expect(perServing.id, 'off-123');
    expect(perServing.brand, 'Brand A');
    expect(perServing.servingName, '1 bar (60 g)');
    expect(perServing.kcal, 240);
    expect(perServing.protein, 20);

    final per100 = OpenFoodFacts.parseProduct({
      'code': '456',
      'product_name': 'Oats',
      'nutriments': {'energy_100g': 1600, 'proteins_100g': '13'},
    })!;
    expect(per100.servingName, '100 g');
    expect(per100.kcal, closeTo(382.4, 0.1), reason: 'kJ converted');
    expect(per100.protein, 13);

    expect(OpenFoodFacts.parseProduct({'code': '1', 'product_name': 'No energy', 'nutriments': {}}), isNull);
    expect(OpenFoodFacts.parseProduct({'code': '1', 'nutriments': {'energy-kcal_100g': 1}}), isNull);
  });

  test('search uses the search service, falling back to the main site when it fails', () async {
    const product = {
      'code': '89',
      'product_name': 'Malai Paneer',
      'brands': ['Amul', 'Other'],
      'nutriments': {'energy-kcal_100g': 314, 'proteins_100g': 20},
    };
    final hosts = <String>[];
    var searchServiceUp = true;
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'search.openfoodfacts.org') {
        return searchServiceUp ? http.Response(jsonEncode({'hits': [product]}), 200) : http.Response('busy', 503);
      }
      return http.Response(jsonEncode({'products': [{...product, 'brands': 'Amul, Other'}]}), 200);
    });
    final off = OpenFoodFacts(client);

    final first = await off.search('paneer');
    expect(first.single.brand, 'Amul', reason: 'brands as a list');
    expect(hosts, ['search.openfoodfacts.org']);

    searchServiceUp = false;
    hosts.clear();
    final fallback = await off.search('paneer');
    expect(fallback.single.brand, 'Amul', reason: 'brands as a string');
    expect(hosts, ['search.openfoodfacts.org', 'world.openfoodfacts.org']);
  });

  test('built-in foods have unique ids and sane numbers', () {
    expect(builtinFoods.map((f) => f.id).toSet().length, builtinFoods.length);
    for (final f in builtinFoods) {
      final fromMacros = f.protein * 4 + f.carbs * 4 + f.fat * 9;
      expect((fromMacros - f.kcal).abs() / f.kcal, lessThan(0.25), reason: '${f.name}: macros roughly match kcal');
    }
  });

  group('logging', () {
    setUpAll(useFfiDatabase);
    setUp(resetDatabase);

    test('logged food is a snapshot; online foods are saved for offline use', () async {
      final provider = NutritionProvider();
      await provider.load();
      final roti = builtinFoods.firstWhere((f) => f.name == 'Roti / chapati');
      await provider.log(roti, meal: 'lunch', servings: 3);

      const bar = Food(id: 'off-9', name: 'Bar', servingName: '1 bar', kcal: 200, protein: 20, carbs: 20, fat: 5, source: 'off');
      await provider.log(bar, meal: 'snacks', servings: 0.5);

      expect(provider.totals.kcal, 3 * 110 + 100);
      expect(provider.totals.protein, closeTo(3 * 3.5 + 10, 0.001));
      expect(provider.totalsFor('lunch').kcal, 330);
      expect(provider.savedFoods.map((f) => f.id), ['off-9'], reason: 'built-ins are not copied');
      expect(provider.recentFoods.map((f) => f.name), containsAll(['Bar', 'Roti / chapati']));

      await provider.deleteLog(provider.logs.first.id);
      expect(provider.logs, hasLength(1));

      await provider.setDay(DateTime.now().subtract(const Duration(days: 1)));
      expect(provider.logs, isEmpty, reason: 'logs are per day');
    });

    test('meal is guessed from the time of day', () {
      expect(mealForNow(DateTime(2026, 1, 1, 8)), 'breakfast');
      expect(mealForNow(DateTime(2026, 1, 1, 13)), 'lunch');
      expect(mealForNow(DateTime(2026, 1, 1, 17)), 'snacks');
      expect(mealForNow(DateTime(2026, 1, 1, 21)), 'dinner');
    });
  });
}
