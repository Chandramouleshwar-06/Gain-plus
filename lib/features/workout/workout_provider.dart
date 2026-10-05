import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/database_service.dart';

class WorkoutExercise {
  final int exerciseId;
  final String name;
  final List<WorkoutSet> sets;

  WorkoutExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
  });
}

class WorkoutSet {
  double weight;
  int reps;
  bool completed;

  WorkoutSet({
    this.weight = 0,
    this.reps = 0,
    this.completed = false,
  });
}

class WorkoutProvider extends ChangeNotifier {
  bool isWorkoutActive = false;
  String activePlanName = '';
  List<WorkoutExercise> exercises = [];
  DateTime? startTime;
  bool _isSaving = false;

  int get completedSetCount =>
      exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.completed).length);

  void startWorkout(String planName, List<WorkoutExercise> workoutExercises) {
    activePlanName = planName;
    exercises = workoutExercises;
    isWorkoutActive = true;
    startTime = DateTime.now();
    notifyListeners();
  }

  void addSet(WorkoutExercise exercise) {
    exercise.sets.add(WorkoutSet());
    notifyListeners();
  }

  void updateSet(WorkoutExercise exercise, int setIndex, double weight, int reps) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].weight = weight;
      exercise.sets[setIndex].reps = reps;
      notifyListeners();
    }
  }

  void toggleSetComplete(WorkoutExercise exercise, int setIndex) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].completed = !exercise.sets[setIndex].completed;
      notifyListeners();
    }
  }

  /// Saves the workout (completed sets only) and ends it. Throws if saving
  /// fails, in which case the workout stays active so nothing is lost.
  Future<void> finishWorkout() async {
    if (!isWorkoutActive || startTime == null || _isSaving) return;

    final duration = DateTime.now().difference(startTime!).inMinutes;
    double totalVolume = 0;
    final entries = <ExerciseEntry>[];

    for (var exercise in exercises) {
      final completedSets = exercise.sets.where((s) => s.completed).toList();
      if (completedSets.isEmpty) continue;

      for (var set in completedSets) {
        totalVolume += set.weight * set.reps;
      }

      entries.add(ExerciseEntry(
        workoutId: 0, // assigned when saved
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        sets: completedSets
            .map((s) => SetEntry(
                  exerciseEntryId: 0, // assigned when saved
                  weight: s.weight,
                  reps: s.reps,
                  completed: true,
                ))
            .toList(),
      ));
    }

    final workout = Workout(
      date: DateTime.now(),
      duration: duration,
      exercises: entries,
      totalVolume: totalVolume,
    );

    _isSaving = true;
    try {
      await DatabaseService.instance.saveCompletedWorkout(workout);
      _reset();
    } finally {
      _isSaving = false;
    }
  }

  void discardWorkout() => _reset();

  void _reset() {
    isWorkoutActive = false;
    activePlanName = '';
    exercises = [];
    startTime = null;
    notifyListeners();
  }
}
