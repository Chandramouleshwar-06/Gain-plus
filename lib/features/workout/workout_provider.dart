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
  int elapsedTime = 0;

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

  Future<void> finishWorkout() async {
    if (!isWorkoutActive || startTime == null) return;

    final duration = DateTime.now().difference(startTime!).inMinutes;
    double totalVolume = 0;

    for (var exercise in exercises) {
      for (var set in exercise.sets) {
        if (set.completed) {
          totalVolume += set.weight * set.reps;
        }
      }
    }

    final workout = Workout(
      date: DateTime.now(),
      duration: duration,
      exercises: [],
      totalVolume: totalVolume,
    );

    final workoutId = await DatabaseService.instance.insertWorkout(workout);

    for (var exercise in exercises) {
      final entry = ExerciseEntry(
        workoutId: workoutId,
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        sets: [],
      );

      final entryId = await DatabaseService.instance.insertExerciseEntry(entry);

      for (var set in exercise.sets) {
        if (set.completed) {
          final setEntry = SetEntry(
            exerciseEntryId: entryId,
            weight: set.weight,
            reps: set.reps,
            completed: true,
          );
          await DatabaseService.instance.insertSetEntry(setEntry);
        }
      }
    }

    isWorkoutActive = false;
    activePlanName = '';
    exercises = [];
    startTime = null;
    elapsedTime = 0;
    notifyListeners();
  }
}
