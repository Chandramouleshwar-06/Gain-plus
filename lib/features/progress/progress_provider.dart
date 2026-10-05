import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/database_service.dart';

class ProgressProvider extends ChangeNotifier {
  int streak = 0;
  int totalWorkouts = 0;
  double totalVolume = 0;
  Map<String, Map<String, dynamic>> personalRecords = {};
  List<Workout> recentWorkouts = [];

  Future<void> loadData() async {
    final workouts = await DatabaseService.instance.getWorkouts();
    recentWorkouts = workouts;
    totalWorkouts = workouts.length;

    totalVolume = 0;
    for (var workout in workouts) {
      totalVolume += workout.totalVolume;
    }

    streak = _calculateStreak(workouts);
    await _calculatePRs();
    notifyListeners();
  }

  int _calculateStreak(List<Workout> workouts) {
    if (workouts.isEmpty) return 0;

    workouts.sort((a, b) => b.date.compareTo(a.date));
    int currentStreak = 0;
    DateTime? lastDate;

    for (var workout in workouts) {
      final workoutDate = DateTime(workout.date.year, workout.date.month, workout.date.day);
      
      if (lastDate == null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        
        if (workoutDate.isAtSameMomentAs(todayDate) || 
            workoutDate.isAtSameMomentAs(todayDate.subtract(const Duration(days: 1)))) {
          currentStreak = 1;
          lastDate = workoutDate;
        } else {
          break;
        }
      } else {
        final expectedDate = lastDate.subtract(const Duration(days: 1));
        if (workoutDate.isAtSameMomentAs(expectedDate)) {
          currentStreak++;
          lastDate = workoutDate;
        } else if (!workoutDate.isAtSameMomentAs(lastDate)) {
          break;
        }
      }
    }

    return currentStreak;
  }

  Future<void> _calculatePRs() async {
    personalRecords.clear();
    final workouts = await DatabaseService.instance.getWorkouts();

    for (var workout in workouts) {
      final exercises = await DatabaseService.instance.getExerciseEntries(workout.id!);
      
      for (var exercise in exercises) {
        for (var set in exercise.sets) {
          if (set.completed) {
            final currentPR = personalRecords[exercise.exerciseName];
            
            if (currentPR == null) {
              personalRecords[exercise.exerciseName] = {
                'weight': set.weight,
                'reps': set.reps,
              };
            } else {
              if (set.weight > currentPR['weight'] ||
                  (set.weight == currentPR['weight'] && set.reps > currentPR['reps'])) {
                personalRecords[exercise.exerciseName] = {
                  'weight': set.weight,
                  'reps': set.reps,
                };
              }
            }
          }
        }
      }
    }
  }
}
