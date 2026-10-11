class Workout {
  final String id;
  final String? planId;
  final String name;
  final DateTime startedAt;
  final int durationSeconds;
  final double totalVolume;

  /// Estimated calories burned, when known.
  final double? kcal;
  final List<ExerciseEntry> exercises;

  Workout({
    required this.id,
    this.planId,
    required this.name,
    required this.startedAt,
    required this.durationSeconds,
    required this.totalVolume,
    this.kcal,
    this.exercises = const [],
  });

  int get durationMinutes => durationSeconds ~/ 60;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'planId': planId,
      'name': name,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'totalVolume': totalVolume,
      'kcal': kcal,
    };
  }

  factory Workout.fromMap(Map<String, Object?> map, [List<ExerciseEntry> exercises = const []]) {
    return Workout(
      id: map['id'] as String,
      planId: map['planId'] as String?,
      name: map['name'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      durationSeconds: map['durationSeconds'] as int,
      totalVolume: (map['totalVolume'] as num).toDouble(),
      kcal: (map['kcal'] as num?)?.toDouble(),
      exercises: exercises,
    );
  }
}

/// One exercise done in a workout. Keeps the exercise name as it was at the
/// time, so history still reads correctly if the exercise is renamed later.
class ExerciseEntry {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int position;
  final List<SetEntry> sets;

  ExerciseEntry({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    required this.sets,
  });

  factory ExerciseEntry.fromMap(Map<String, Object?> map, List<SetEntry> sets) {
    return ExerciseEntry(
      id: map['id'] as String,
      exerciseId: map['exerciseId'] as String,
      exerciseName: map['exerciseName'] as String,
      position: map['position'] as int,
      sets: sets,
    );
  }
}

/// A completed set. Only completed sets are saved.
/// Kinds of set. Warm-ups don't count towards volume, PRs or progress.
class SetType {
  static const normal = 'normal';
  static const warmup = 'warmup';
  static const drop = 'drop';
  static const failure = 'failure';

  static const all = [normal, warmup, drop, failure];
}

class SetEntry {
  final String id;
  final int position;
  final double weight;
  final int reps;
  final String setType;

  /// Rate of perceived exertion, 1-10 (half steps), if recorded.
  final double? rpe;

  SetEntry({
    required this.id,
    required this.position,
    required this.weight,
    required this.reps,
    this.setType = SetType.normal,
    this.rpe,
  });

  bool get isWarmup => setType == SetType.warmup;

  factory SetEntry.fromMap(Map<String, Object?> map) {
    return SetEntry(
      id: map['id'] as String,
      position: map['position'] as int,
      weight: (map['weight'] as num).toDouble(),
      reps: map['reps'] as int,
      setType: map['setType'] as String? ?? SetType.normal,
      rpe: (map['rpe'] as num?)?.toDouble(),
    );
  }
}
