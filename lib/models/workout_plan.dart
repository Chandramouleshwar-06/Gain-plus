class WorkoutPlan {
  final String id;
  final String name;

  /// Exercises in the order they're done.
  final List<PlanExercise> items;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.items,
  });

  List<String> get exerciseIds => items.map((i) => i.exerciseId).toList();

  factory WorkoutPlan.fromMap(Map<String, Object?> map, List<PlanExercise> items) {
    return WorkoutPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      items: items,
    );
  }
}

class PlanExercise {
  final String id;
  final String exerciseId;
  final int position;
  final int targetSets;

  /// Null when reps don't apply (e.g. a timed plank).
  final int? targetReps;

  PlanExercise({
    required this.id,
    required this.exerciseId,
    required this.position,
    this.targetSets = 3,
    this.targetReps,
  });

  factory PlanExercise.fromMap(Map<String, Object?> map) {
    return PlanExercise(
      id: map['id'] as String,
      exerciseId: map['exerciseId'] as String,
      position: map['position'] as int,
      targetSets: map['targetSets'] as int,
      targetReps: map['targetReps'] as int?,
    );
  }
}
