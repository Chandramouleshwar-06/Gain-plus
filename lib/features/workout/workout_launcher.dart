import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exercise.dart';
import '../../models/workout_plan.dart';
import '../exercise/exercise_provider.dart';
import 'overload.dart';
import 'workout_provider.dart';
import 'workout_screen.dart';

/// Opens the workout in progress full-screen.
Future<void> openActiveWorkout(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const WorkoutScreen()),
  );
}

/// Starts [plan] (each exercise with its target number of sets) and opens
/// the workout. Exercises that no longer exist are skipped.
Future<void> startPlanWorkout(BuildContext context, WorkoutPlan plan) async {
  final exerciseProvider = context.read<ExerciseProvider>();
  final workoutProvider = context.read<WorkoutProvider>();
  final messenger = ScaffoldMessenger.of(context);

  if (workoutProvider.isWorkoutActive) {
    await openActiveWorkout(context);
    return;
  }

  if (exerciseProvider.exercises.isEmpty) {
    await exerciseProvider.loadExercises();
  }

  final workoutExercises = <WorkoutExercise>[];
  for (final item in plan.items) {
    final exercise = exerciseProvider.byId(item.exerciseId);
    if (exercise == null) continue;
    workoutExercises.add(workoutExerciseFor(exercise, sets: item.targetSets, targetReps: item.targetReps));
  }

  if (workoutExercises.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text('${plan.name} has no exercises yet. Add some in Train.')),
    );
    return;
  }

  workoutProvider.startWorkout(plan.id, plan.name, workoutExercises);
  if (context.mounted) await openActiveWorkout(context);
}

/// Rough session length: about 2.5 minutes per set including rest,
/// rounded to 5 minutes.
int estimateMinutes(WorkoutPlan plan) {
  final sets = plan.items.fold(0, (sum, i) => sum + i.targetSets);
  return ((sets * 2.5) / 5).round() * 5;
}

/// Formats a duration as m:ss, or h:mm:ss past an hour.
String formatElapsed(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds' : '$minutes:$seconds';
}

/// A workout entry for [exercise] with [sets] empty sets.
WorkoutExercise workoutExerciseFor(Exercise exercise, {int sets = 3, int? targetReps}) => WorkoutExercise(
      exerciseId: exercise.id,
      name: exercise.name,
      sets: [for (var i = 0; i < sets; i++) WorkoutSet()],
      targetReps: targetReps,
      lowerBody: isLowerBody(exerciseName: exercise.name, muscleGroup: exercise.muscleGroup),
    );

/// Starts a workout with no exercises; they're added as you go.
Future<void> startEmptyWorkout(BuildContext context) async {
  final workoutProvider = context.read<WorkoutProvider>();
  if (!workoutProvider.isWorkoutActive) {
    workoutProvider.startWorkout(null, 'Quick workout', []);
  }
  await openActiveWorkout(context);
}
