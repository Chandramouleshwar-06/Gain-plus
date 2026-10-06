// Built-in exercises and plans seeded on every device.
//
// They use fixed IDs (not random UUIDs) so that the same built-in row on
// two devices is the same row once data syncs.

/// Stable ID for a built-in exercise, e.g. `builtin-ex-bench-press-barbell`.
String builtinExerciseId(String name) => 'builtin-ex-${_slug(name)}';

String builtinPlanId(String key) => 'builtin-plan-$key';

String _slug(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

class SeedExercise {
  final String name;
  final String muscleGroup;
  final String notes;

  const SeedExercise(this.name, this.muscleGroup, this.notes);

  String get id => builtinExerciseId(name);
}

class SeedPlan {
  final String key;
  final String name;
  final List<String> exerciseNames;

  const SeedPlan(this.key, this.name, this.exerciseNames);

  String get id => builtinPlanId(key);
}

const seedExercises = [
  // Chest
  SeedExercise('Bench Press (Barbell)', 'Chest', 'Middle chest'),
  SeedExercise('Incline Bench Press (Barbell)', 'Chest', 'Upper chest'),
  SeedExercise('Dumbbell Flys', 'Chest', 'Chest isolation'),
  SeedExercise('Push Ups', 'Chest', 'Bodyweight calisthenics'),
  SeedExercise('Chest Press (Machine)', 'Chest', 'Controlled movement'),
  SeedExercise('Diamond Push Ups', 'Chest/Triceps', 'Inner chest focused calisthenics'),
  SeedExercise('Dips (Chest Focus)', 'Chest/Triceps', 'Leaning forward calisthenics'),

  // Legs
  SeedExercise('Squat (Barbell)', 'Legs', 'Quads and Glutes'),
  SeedExercise('Leg Press', 'Legs', 'Machine quads'),
  SeedExercise('Leg Extension', 'Legs', 'Quad isolation'),
  SeedExercise('Leg Curl', 'Legs', 'Hamstrings'),
  SeedExercise('Lunges (Dumbbell)', 'Legs', 'Unilateral legs'),
  SeedExercise('Calf Raise', 'Legs', 'Calves'),
  SeedExercise('Pistol Squats', 'Legs', 'Advanced unilateral calisthenics'),
  SeedExercise('Bulgarian Split Squats', 'Legs', 'Quad focus'),

  // Back
  SeedExercise('Deadlift (Barbell)', 'Back', 'Posterior chain'),
  SeedExercise('Pull Up', 'Back', 'Width calisthenics'),
  SeedExercise('Chin Up', 'Back/Biceps', 'Bicep focus calisthenics'),
  SeedExercise('Lat Pulldown', 'Back', 'Width - Machine'),
  SeedExercise('Barbell Row', 'Back', 'Thickness'),
  SeedExercise('Seated Cable Row', 'Back', 'Middle back'),
  SeedExercise('Dumbbell Row', 'Back', 'Single arm back'),
  SeedExercise('Australian Pull Ups', 'Back', 'Inverted rows calisthenics'),
  SeedExercise('Muscle Up', 'Back/Arms', 'Explosive calisthenics'),

  // Shoulders
  SeedExercise('Overhead Press (Barbell)', 'Shoulders', 'Front/Side delts'),
  SeedExercise('Lateral Raise (Dumbbell)', 'Shoulders', 'Side delt isolation'),
  SeedExercise('Front Raise (Dumbbell)', 'Shoulders', 'Front delt isolation'),
  SeedExercise('Shoulder Press (Dumbbell)', 'Shoulders', 'Stability shoulders'),
  SeedExercise('Rear Delt Fly (Machine)', 'Shoulders', 'Rear delt isolation'),
  SeedExercise('Handstand Push Ups', 'Shoulders', 'Advanced shoulder calisthenics'),
  SeedExercise('Pike Push Ups', 'Shoulders', 'Shoulder focus calisthenics'),

  // Arms
  SeedExercise('Bicep Curl (Dumbbell)', 'Biceps', 'Biceps'),
  SeedExercise('Hammer Curl (Dumbbell)', 'Biceps', 'Brachialis/Forearms'),
  SeedExercise('Tricep Pushdown (Cable)', 'Triceps', 'Tricep isolation'),
  SeedExercise('Tricep Dip', 'Triceps', 'Parallel bar calisthenics'),
  SeedExercise('Preacher Curl', 'Biceps', 'Bicep isolation'),
  SeedExercise('Skull Crushers', 'Triceps', 'Tricep extension'),

  // Core & Full Body
  SeedExercise('Plank', 'Core', 'Stability'),
  SeedExercise('Crunches', 'Core', 'Abs'),
  SeedExercise('Leg Raise', 'Core', 'Lower abs calisthenics'),
  SeedExercise('L-Sit', 'Core/Arms', 'Isometric calisthenics'),
  SeedExercise('Burpees', 'Full Body', 'Conditioning calisthenics'),
  SeedExercise('Hollow Body Hold', 'Core', 'Core foundation'),
];

const seedPlans = [
  SeedPlan('push', 'Push (Chest/Shoulders/Triceps)', [
    'Bench Press (Barbell)',
    'Overhead Press (Barbell)',
    'Incline Bench Press (Barbell)',
    'Lateral Raise (Dumbbell)',
    'Tricep Pushdown (Cable)',
    'Dips (Chest Focus)',
  ]),
  SeedPlan('pull', 'Pull (Back/Biceps)', [
    'Deadlift (Barbell)',
    'Pull Up',
    'Barbell Row',
    'Seated Cable Row',
    'Bicep Curl (Dumbbell)',
    'Hammer Curl (Dumbbell)',
  ]),
  SeedPlan('legs', 'Legs (Quads/Hams/Calves)', [
    'Squat (Barbell)',
    'Leg Press',
    'Leg Extension',
    'Leg Curl',
    'Bulgarian Split Squats',
    'Calf Raise',
  ]),
  SeedPlan('calisthenics', 'Calisthenics Basic', [
    'Push Ups',
    'Pull Up',
    'Dips (Chest Focus)',
    'Australian Pull Ups',
    'Pike Push Ups',
    'Leg Raise',
  ]),
  SeedPlan('full-body', 'Full Body (Basic)', [
    'Squat (Barbell)',
    'Bench Press (Barbell)',
    'Barbell Row',
    'Overhead Press (Barbell)',
    'Plank',
  ]),
];
