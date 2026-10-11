/// A food with nutrition per serving.
class Food {
  final String id;
  final String name;
  final String? brand;

  /// What one serving is, e.g. "1 medium", "1 katori (150 g)".
  final String servingName;

  /// Grams in one serving, when known (lets you log by weight).
  final double? servingGrams;

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// 'builtin', 'custom' or 'off' (Open Food Facts).
  final String source;

  const Food({
    required this.id,
    required this.name,
    this.brand,
    required this.servingName,
    this.servingGrams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.source = 'custom',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'servingName': servingName,
        'servingGrams': servingGrams,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'source': source,
      };

  factory Food.fromMap(Map<String, Object?> map) => Food(
        id: map['id'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        servingName: map['servingName'] as String,
        servingGrams: (map['servingGrams'] as num?)?.toDouble(),
        kcal: (map['kcal'] as num).toDouble(),
        protein: (map['protein'] as num).toDouble(),
        carbs: (map['carbs'] as num).toDouble(),
        fat: (map['fat'] as num).toDouble(),
        source: map['source'] as String,
      );
}

/// Meals of the day, in order.
const meals = ['breakfast', 'lunch', 'dinner', 'snacks'];

String mealLabel(String meal) => switch (meal) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      _ => 'Snacks',
    };

/// Something eaten: a snapshot of the food's totals for [servings].
class FoodLog {
  final String id;
  final DateTime date;
  final String meal;
  final String? foodId;
  final String name;
  final double servings;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const FoodLog({
    required this.id,
    required this.date,
    required this.meal,
    this.foodId,
    required this.name,
    required this.servings,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

/// Calories and macros added up.
class Macros {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const Macros({this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  Macros operator +(Macros o) =>
      Macros(kcal: kcal + o.kcal, protein: protein + o.protein, carbs: carbs + o.carbs, fat: fat + o.fat);

  static Macros of(Iterable<FoodLog> logs) => logs.fold(
        const Macros(),
        (sum, l) => sum + Macros(kcal: l.kcal, protein: l.protein, carbs: l.carbs, fat: l.fat),
      );
}
