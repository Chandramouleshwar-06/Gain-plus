class Workout {
  final int? id;
  final DateTime date;
  final int duration;
  final List<ExerciseEntry> exercises;
  final double totalVolume;

  Workout({
    this.id,
    required this.date,
    required this.duration,
    required this.exercises,
    required this.totalVolume,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'duration': duration,
      'totalVolume': totalVolume,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      date: DateTime.parse(map['date']),
      duration: map['duration'],
      exercises: [],
      totalVolume: map['totalVolume'],
    );
  }
}

class ExerciseEntry {
  final int? id;
  final int workoutId;
  final int exerciseId;
  final String exerciseName;
  final List<SetEntry> sets;

  ExerciseEntry({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
    };
  }

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) {
    return ExerciseEntry(
      id: map['id'],
      workoutId: map['workoutId'],
      exerciseId: map['exerciseId'],
      exerciseName: map['exerciseName'],
      sets: [],
    );
  }
}

class SetEntry {
  final int? id;
  final int exerciseEntryId;
  final double weight;
  final int reps;
  final bool completed;

  SetEntry({
    this.id,
    required this.exerciseEntryId,
    required this.weight,
    required this.reps,
    required this.completed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseEntryId': exerciseEntryId,
      'weight': weight,
      'reps': reps,
      'completed': completed ? 1 : 0,
    };
  }

  factory SetEntry.fromMap(Map<String, dynamic> map) {
    return SetEntry(
      id: map['id'],
      exerciseEntryId: map['exerciseEntryId'],
      weight: map['weight'],
      reps: map['reps'],
      completed: map['completed'] == 1,
    );
  }
}
