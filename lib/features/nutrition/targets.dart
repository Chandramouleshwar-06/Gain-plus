/// Daily calorie and macro targets.
class NutritionTargets {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionTargets({required this.kcal, required this.protein, required this.carbs, required this.fat});
}

const activityLevels = <(String, String, String, double)>[
  ('sedentary', 'Sedentary', 'Desk job, little walking', 1.2),
  ('light', 'Lightly active', 'Some walking, training 1-3 days', 1.375),
  ('moderate', 'Moderately active', 'On your feet, training 3-5 days', 1.55),
  ('active', 'Very active', 'Physical job or training 6-7 days', 1.725),
  ('very_active', 'Athlete', 'Hard training twice a day', 1.9),
];

/// What's needed for targets that isn't filled in yet.
List<String> missingForTargets({
  double? weightKg,
  double? heightCm,
  int? birthYear,
  String? sex,
  String? activityLevel,
}) =>
    [
      if (weightKg == null) 'body weight',
      if (heightCm == null) 'height',
      if (birthYear == null) 'year of birth',
      if (sex == null) 'sex',
      if (activityLevel == null) 'activity level',
    ];

/// Mifflin-St Jeor resting burn x activity, adjusted for the goal.
/// Protein per kg of body weight depends on the goal; fat is 25% of
/// calories and carbs make up the rest. Returns null if anything's missing.
NutritionTargets? calculateTargets({
  required double? weightKg,
  required double? heightCm,
  required int? birthYear,
  required String? sex,
  required String? activityLevel,
  required String? goal,
  required int currentYear,
}) {
  if (weightKg == null || heightCm == null || birthYear == null || sex == null || activityLevel == null) {
    return null;
  }
  final age = currentYear - birthYear;
  final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == 'female' ? -161 : 5);
  final factor = activityLevels.where((a) => a.$1 == activityLevel).firstOrNull?.$4 ?? 1.375;
  final maintenance = bmr * factor;

  final (calorieChange, proteinPerKg) = switch (goal) {
    'lose_fat' => (-0.20, 2.0),
    'build_muscle' => (0.10, 1.8),
    'get_stronger' => (0.05, 1.8),
    _ => (0.0, 1.4),
  };
  final kcal = (maintenance * (1 + calorieChange) / 10).round() * 10.0;
  final protein = (weightKg * proteinPerKg).roundToDouble();
  final fat = (kcal * 0.25 / 9).roundToDouble();
  final carbs = ((kcal - protein * 4 - fat * 9) / 4).clamp(0, double.infinity).roundToDouble();
  return NutritionTargets(kcal: kcal, protein: protein, carbs: carbs, fat: fat);
}
