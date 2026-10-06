import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/sync_columns.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';

class WorkoutExercise {
  final String exerciseId;
  final String name;
  final List<WorkoutSet> sets;

  WorkoutExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
  });

  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>)).toList(),
      );
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

  Map<String, Object?> toJson() => {'weight': weight, 'reps': reps, 'completed': completed};

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        weight: (json['weight'] as num).toDouble(),
        reps: json['reps'] as int,
        completed: json['completed'] as bool,
      );
}

class WorkoutProvider extends ChangeNotifier {
  bool isWorkoutActive = false;
  String? activePlanId;
  String activePlanName = '';
  List<WorkoutExercise> exercises = [];
  DateTime? startTime;
  bool _isSaving = false;
  Timer? _persistTimer;

  int get completedSetCount =>
      exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.completed).length);

  /// Restores a workout that was in progress when the app was last closed.
  Future<void> restore() async {
    try {
      final data = await ActiveWorkoutStore.instance.load();
      if (data == null) return;
      final json = jsonDecode(data) as Map<String, dynamic>;
      activePlanId = json['planId'] as String?;
      activePlanName = json['planName'] as String;
      startTime = DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int);
      exercises = (json['exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList();
      isWorkoutActive = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not restore active workout: $e');
    }
  }

  void startWorkout(String? planId, String planName, List<WorkoutExercise> workoutExercises) {
    activePlanId = planId;
    activePlanName = planName;
    exercises = workoutExercises;
    isWorkoutActive = true;
    startTime = DateTime.now();
    _changed();
  }

  void addSet(WorkoutExercise exercise) {
    exercise.sets.add(WorkoutSet());
    _changed();
  }

  void updateSet(WorkoutExercise exercise, int setIndex, double weight, int reps) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].weight = weight;
      exercise.sets[setIndex].reps = reps;
      _changed();
    }
  }

  void toggleSetComplete(WorkoutExercise exercise, int setIndex) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].completed = !exercise.sets[setIndex].completed;
      _changed();
    }
  }

  /// Saves the workout (completed sets only) and ends it. Throws if saving
  /// fails, in which case the workout stays active so nothing is lost.
  Future<void> finishWorkout() async {
    if (!isWorkoutActive || startTime == null || _isSaving) return;

    double totalVolume = 0;
    final entries = <ExerciseEntry>[];

    for (var exercise in exercises) {
      final completedSets = exercise.sets.where((s) => s.completed).toList();
      if (completedSets.isEmpty) continue;

      for (var set in completedSets) {
        totalVolume += set.weight * set.reps;
      }

      entries.add(ExerciseEntry(
        id: newId(),
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        position: entries.length,
        sets: [
          for (var i = 0; i < completedSets.length; i++)
            SetEntry(
              id: newId(),
              position: i,
              weight: completedSets[i].weight,
              reps: completedSets[i].reps,
            ),
        ],
      ));
    }

    final workout = Workout(
      id: newId(),
      planId: activePlanId,
      name: activePlanName,
      startedAt: startTime!,
      durationSeconds: DateTime.now().difference(startTime!).inSeconds,
      totalVolume: totalVolume,
      exercises: entries,
    );

    _isSaving = true;
    try {
      await WorkoutRepository.instance.save(workout);
      await _reset();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> discardWorkout() => _reset();

  Future<void> _reset() async {
    _persistTimer?.cancel();
    isWorkoutActive = false;
    activePlanId = null;
    activePlanName = '';
    exercises = [];
    startTime = null;
    notifyListeners();
    await ActiveWorkoutStore.instance.clear();
  }

  void _changed() {
    notifyListeners();
    // Debounced so typing weights doesn't write on every keystroke.
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _persist() async {
    if (!isWorkoutActive || startTime == null) return;
    try {
      await ActiveWorkoutStore.instance.save(jsonEncode({
        'planId': activePlanId,
        'planName': activePlanName,
        'startedAt': startTime!.millisecondsSinceEpoch,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      }));
    } catch (e) {
      debugPrint('Could not save active workout: $e');
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}
