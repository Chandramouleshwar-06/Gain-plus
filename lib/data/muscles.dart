import '../models/exercise.dart';

/// Muscles tracked for recovery and balance.
enum Muscle {
  chest('Chest', 'Chest', 72),
  frontDelts('Front delts', 'Shoulders', 48),
  sideDelts('Side delts', 'Shoulders', 48),
  rearDelts('Rear delts', 'Shoulders', 48),
  biceps('Biceps', 'Arms', 48),
  triceps('Triceps', 'Arms', 48),
  forearms('Forearms', 'Arms', 48),
  traps('Traps', 'Back', 48),
  lats('Lats', 'Back', 72),
  upperBack('Upper back', 'Back', 72),
  lowerBack('Lower back', 'Back', 72),
  abs('Abs', 'Core', 48),
  quads('Quads', 'Legs', 72),
  hamstrings('Hamstrings', 'Legs', 72),
  glutes('Glutes', 'Legs', 72),
  calves('Calves', 'Legs', 48);

  const Muscle(this.label, this.group, this.recoveryHours);

  final String label;

  /// Broad group for the balance chart.
  final String group;

  /// Roughly how long a hard session takes to recover from.
  final int recoveryHours;

  static const groups = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core'];
}

/// Which muscles an exercise works: (primary, secondary).
typedef MuscleMap = (List<Muscle>, List<Muscle>);

const _builtinMuscles = <String, MuscleMap>{
  'Bench Press (Barbell)': ([Muscle.chest], [Muscle.frontDelts, Muscle.triceps]),
  'Incline Bench Press (Barbell)': ([Muscle.chest, Muscle.frontDelts], [Muscle.triceps]),
  'Dumbbell Flys': ([Muscle.chest], [Muscle.frontDelts]),
  'Push Ups': ([Muscle.chest], [Muscle.frontDelts, Muscle.triceps, Muscle.abs]),
  'Chest Press (Machine)': ([Muscle.chest], [Muscle.frontDelts, Muscle.triceps]),
  'Diamond Push Ups': ([Muscle.triceps, Muscle.chest], [Muscle.frontDelts]),
  'Dips (Chest Focus)': ([Muscle.chest, Muscle.triceps], [Muscle.frontDelts]),
  'Squat (Barbell)': ([Muscle.quads, Muscle.glutes], [Muscle.hamstrings, Muscle.lowerBack, Muscle.abs]),
  'Leg Press': ([Muscle.quads, Muscle.glutes], [Muscle.hamstrings]),
  'Leg Extension': ([Muscle.quads], []),
  'Leg Curl': ([Muscle.hamstrings], [Muscle.calves]),
  'Lunges (Dumbbell)': ([Muscle.quads, Muscle.glutes], [Muscle.hamstrings]),
  'Calf Raise': ([Muscle.calves], []),
  'Pistol Squats': ([Muscle.quads, Muscle.glutes], [Muscle.hamstrings, Muscle.abs]),
  'Bulgarian Split Squats': ([Muscle.quads, Muscle.glutes], [Muscle.hamstrings]),
  'Deadlift (Barbell)': ([Muscle.hamstrings, Muscle.glutes, Muscle.lowerBack], [Muscle.traps, Muscle.upperBack, Muscle.forearms, Muscle.quads]),
  'Pull Up': ([Muscle.lats], [Muscle.biceps, Muscle.upperBack, Muscle.forearms]),
  'Chin Up': ([Muscle.lats, Muscle.biceps], [Muscle.upperBack, Muscle.forearms]),
  'Lat Pulldown': ([Muscle.lats], [Muscle.biceps, Muscle.upperBack]),
  'Barbell Row': ([Muscle.upperBack, Muscle.lats], [Muscle.rearDelts, Muscle.biceps, Muscle.lowerBack]),
  'Seated Cable Row': ([Muscle.upperBack, Muscle.lats], [Muscle.rearDelts, Muscle.biceps]),
  'Dumbbell Row': ([Muscle.lats, Muscle.upperBack], [Muscle.rearDelts, Muscle.biceps]),
  'Australian Pull Ups': ([Muscle.upperBack, Muscle.lats], [Muscle.rearDelts, Muscle.biceps]),
  'Muscle Up': ([Muscle.lats, Muscle.triceps], [Muscle.chest, Muscle.biceps, Muscle.abs]),
  'Overhead Press (Barbell)': ([Muscle.frontDelts, Muscle.sideDelts], [Muscle.triceps, Muscle.traps, Muscle.abs]),
  'Lateral Raise (Dumbbell)': ([Muscle.sideDelts], [Muscle.traps]),
  'Front Raise (Dumbbell)': ([Muscle.frontDelts], []),
  'Shoulder Press (Dumbbell)': ([Muscle.frontDelts, Muscle.sideDelts], [Muscle.triceps]),
  'Rear Delt Fly (Machine)': ([Muscle.rearDelts], [Muscle.upperBack]),
  'Handstand Push Ups': ([Muscle.frontDelts, Muscle.triceps], [Muscle.sideDelts, Muscle.traps]),
  'Pike Push Ups': ([Muscle.frontDelts], [Muscle.triceps, Muscle.chest]),
  'Bicep Curl (Dumbbell)': ([Muscle.biceps], [Muscle.forearms]),
  'Hammer Curl (Dumbbell)': ([Muscle.biceps, Muscle.forearms], []),
  'Tricep Pushdown (Cable)': ([Muscle.triceps], []),
  'Tricep Dip': ([Muscle.triceps], [Muscle.chest, Muscle.frontDelts]),
  'Preacher Curl': ([Muscle.biceps], [Muscle.forearms]),
  'Skull Crushers': ([Muscle.triceps], []),
  'Plank': ([Muscle.abs], [Muscle.lowerBack]),
  'Crunches': ([Muscle.abs], []),
  'Leg Raise': ([Muscle.abs], [Muscle.forearms]),
  'L-Sit': ([Muscle.abs], [Muscle.triceps, Muscle.quads]),
  'Burpees': ([Muscle.quads, Muscle.chest], [Muscle.glutes, Muscle.frontDelts, Muscle.triceps, Muscle.abs]),
  'Hollow Body Hold': ([Muscle.abs], []),
};

/// Best guess from a free-text muscle group, for custom exercises:
/// "Back/Biceps" -> lats + upper back, biceps.
MuscleMap _fromMuscleGroup(String muscleGroup) {
  final primary = <Muscle>[];
  final secondary = <Muscle>[];
  final parts = muscleGroup.toLowerCase().split('/').map((s) => s.trim()).toList();
  for (var i = 0; i < parts.length; i++) {
    final into = i == 0 ? primary : secondary;
    into.addAll(switch (parts[i]) {
      String p when p.contains('chest') || p.contains('pec') => [Muscle.chest],
      String p when p.contains('lat') => [Muscle.lats],
      String p when p.contains('back') => [Muscle.lats, Muscle.upperBack],
      String p when p.contains('shoulder') || p.contains('delt') => [Muscle.frontDelts, Muscle.sideDelts],
      String p when p.contains('bicep') => [Muscle.biceps],
      String p when p.contains('tricep') => [Muscle.triceps],
      String p when p.contains('arm') => [Muscle.biceps, Muscle.triceps],
      String p when p.contains('forearm') || p.contains('grip') => [Muscle.forearms],
      String p when p.contains('quad') => [Muscle.quads],
      String p when p.contains('hamstring') => [Muscle.hamstrings],
      String p when p.contains('glute') => [Muscle.glutes],
      String p when p.contains('calf') || p.contains('calves') => [Muscle.calves],
      String p when p.contains('leg') => [Muscle.quads, Muscle.hamstrings, Muscle.glutes],
      String p when p.contains('core') || p.contains('ab') => [Muscle.abs],
      String p when p.contains('full') => [Muscle.quads, Muscle.chest, Muscle.lats],
      _ => const <Muscle>[],
    });
  }
  return (primary, secondary);
}

/// The muscles [exercise] works.
MuscleMap musclesFor(Exercise exercise) =>
    (exercise.isCustom ? null : _builtinMuscles[exercise.name]) ?? _fromMuscleGroup(exercise.muscleGroup);

/// Muscles for a logged exercise name with no matching exercise (e.g. a
/// deleted custom one): built-in table first, otherwise nothing.
MuscleMap? musclesForName(String name) => _builtinMuscles[name];
