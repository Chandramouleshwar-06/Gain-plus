import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/sync_columns.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../../services/notification_service.dart';

class WorkoutExercise {
  final String exerciseId;
  final String name;
  final List<WorkoutSet> sets;

  /// Reps to aim for per set (from the plan), if any.
  final int? targetReps;

  /// Lower-body lifts progress in bigger weight steps.
  final bool lowerBody;

  WorkoutExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.targetReps,
    this.lowerBody = false,
  });

  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'targetReps': targetReps,
        'lowerBody': lowerBody,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>)).toList(),
        targetReps: json['targetReps'] as int?,
        // Workouts saved by the previous version stored a kg increment.
        lowerBody: json['lowerBody'] as bool? ?? ((json['increment'] as num?) ?? 0) >= 5,
      );
}

class WorkoutSet {
  double weight;
  int reps;
  bool completed;

  /// One of [SetType].
  String setType;

  /// How hard it felt, 1-10, if recorded.
  double? rpe;

  WorkoutSet({
    this.weight = 0,
    this.reps = 0,
    this.completed = false,
    this.setType = SetType.normal,
    this.rpe,
  });

  bool get isWarmup => setType == SetType.warmup;

  Map<String, Object?> toJson() =>
      {'weight': weight, 'reps': reps, 'completed': completed, 'setType': setType, 'rpe': rpe};

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        weight: (json['weight'] as num).toDouble(),
        reps: json['reps'] as int,
        completed: json['completed'] as bool,
        setType: json['setType'] as String? ?? SetType.normal,
        rpe: (json['rpe'] as num?)?.toDouble(),
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

  /// When the current rest ends, or null when not resting.
  DateTime? restEndsAt;

  /// Length of the current rest, for the progress bar.
  int restTotalSeconds = 0;

  bool get isResting => restEndsAt != null;

  /// Sets from the last time each exercise was done, keyed by exercise ID.
  Map<String, List<SetEntry>> previousSets = {};

  Future<void> _loadPreviousSets() async {
    final ids = exercises.map((e) => e.exerciseId).toSet();
    final result = <String, List<SetEntry>>{};
    try {
      for (final id in ids) {
        result[id] = await WorkoutRepository.instance.getLastSets(id);
      }
    } catch (e) {
      debugPrint('Could not load previous sets: $e');
    }
    previousSets = result;
    notifyListeners();
  }

  /// A set only counts (and is saved) when it's ticked off and has reps;
  /// a ticked set left empty would otherwise save as 0 × 0.
  static bool _counts(WorkoutSet s) => s.completed && s.reps > 0;

  int get completedSetCount => exercises.fold(0, (sum, e) => sum + e.sets.where(_counts).length);

  /// Restores a workout that was in progress when the app was last closed.
  Future<void> restore() async {
    try {
      final data = await ActiveWorkoutStore.instance.load();
      if (data == null) return;
      final json = jsonDecode(data) as Map<String, dynamic>;
      activePlanId = json['planId'] as String?;
      activePlanName = json['planName'] as String;
      startTime = DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int);
      final restEnd = json['restEndsAt'] as int?;
      if (restEnd != null && restEnd > DateTime.now().millisecondsSinceEpoch) {
        restEndsAt = DateTime.fromMillisecondsSinceEpoch(restEnd);
        restTotalSeconds = json['restTotalSeconds'] as int? ?? 0;
      }
      exercises = (json['exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList();
      isWorkoutActive = true;
      notifyListeners();
      await _loadPreviousSets();
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
    previousSets = {};
    _changed();
    _loadPreviousSets();
  }

  /// Adds an exercise to the end of the workout.
  void addExercise(WorkoutExercise exercise) {
    exercises.add(exercise);
    _changed();
    _loadPreviousSets();
  }

  /// Swaps the exercise at [index] for [replacement], keeping how many sets
  /// were planned. Logged values are cleared since they were for the old one.
  void replaceExercise(int index, WorkoutExercise replacement) {
    if (index < 0 || index >= exercises.length) return;
    final setCount = exercises[index].sets.length;
    exercises[index] = WorkoutExercise(
      exerciseId: replacement.exerciseId,
      name: replacement.name,
      sets: [for (var i = 0; i < (setCount == 0 ? 1 : setCount); i++) WorkoutSet()],
      targetReps: replacement.targetReps,
      lowerBody: replacement.lowerBody,
    );
    _changed();
    _loadPreviousSets();
  }

  void removeExercise(int index) {
    if (index < 0 || index >= exercises.length) return;
    exercises.removeAt(index);
    _changed();
  }

  /// Moves the exercise at [from] to [to] (both indices in the current list).
  void moveExercise(int from, int to) {
    if (from < 0 || from >= exercises.length || to < 0 || to >= exercises.length || from == to) return;
    exercises.insert(to, exercises.removeAt(from));
    _changed();
  }

  void setSetType(WorkoutExercise exercise, int setIndex, String type) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].setType = type;
      _changed();
    }
  }

  void setRpe(WorkoutExercise exercise, int setIndex, double? rpe) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].rpe = rpe;
      _changed();
    }
  }

  void addSet(WorkoutExercise exercise) {
    exercise.sets.add(WorkoutSet());
    _changed();
  }

  void removeSet(WorkoutExercise exercise, int setIndex) {
    if (setIndex < exercise.sets.length) {
      exercise.sets.removeAt(setIndex);
      _changed();
    }
  }

  void updateSet(WorkoutExercise exercise, int setIndex, double weight, int reps) {
    if (setIndex < exercise.sets.length) {
      exercise.sets[setIndex].weight = weight;
      exercise.sets[setIndex].reps = reps;
      _changed();
    }
  }

  /// Ticks a set on or off. Ticking one on starts a rest of [restSeconds]
  /// when given.
  void toggleSetComplete(WorkoutExercise exercise, int setIndex, {int? restSeconds}) {
    if (setIndex < exercise.sets.length) {
      final set = exercise.sets[setIndex];
      set.completed = !set.completed;
      if (set.completed && restSeconds != null && restSeconds > 0) {
        startRest(restSeconds);
      } else {
        _changed();
      }
    }
  }

  void startRest(int seconds) {
    restTotalSeconds = seconds;
    restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    _scheduleRestNotification();
    _changed();
  }

  /// Adds (or with a negative value, removes) time from the current rest.
  void adjustRest(int seconds) {
    if (restEndsAt == null) return;
    restEndsAt = restEndsAt!.add(Duration(seconds: seconds));
    restTotalSeconds = (restTotalSeconds + seconds).clamp(1, 3600);
    if (!restEndsAt!.isAfter(DateTime.now())) {
      endRest();
      return;
    }
    _scheduleRestNotification();
    _changed();
  }

  /// Stops the rest timer (skipped, or it ran out).
  void endRest() {
    if (restEndsAt == null) return;
    restEndsAt = null;
    _cancelRestNotification();
    _changed();
  }

  void _scheduleRestNotification() {
    final at = restEndsAt;
    if (at == null) return;
    NotificationService.instance.scheduleRestOver(at).catchError((Object e) {
      debugPrint('Could not schedule rest notification: $e');
    });
  }

  void _cancelRestNotification() {
    NotificationService.instance.cancelRestOver().catchError((Object e) {
      debugPrint('Could not cancel rest notification: $e');
    });
  }

  /// Saves the workout (completed sets only) and ends it. Throws if saving
  /// fails, in which case the workout stays active so nothing is lost.
  Future<void> finishWorkout() async {
    if (!isWorkoutActive || startTime == null || _isSaving) return;

    double totalVolume = 0;
    final entries = <ExerciseEntry>[];

    for (var exercise in exercises) {
      final completedSets = exercise.sets.where(_counts).toList();
      if (completedSets.isEmpty) continue;

      for (var set in completedSets) {
        if (!set.isWarmup) totalVolume += set.weight * set.reps;
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
              setType: completedSets[i].setType,
              rpe: completedSets[i].rpe,
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
    if (restEndsAt != null) _cancelRestNotification();
    restEndsAt = null;
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
        'restEndsAt': restEndsAt?.millisecondsSinceEpoch,
        'restTotalSeconds': restTotalSeconds,
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
