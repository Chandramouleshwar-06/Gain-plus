import 'package:flutter/material.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';

class PersonalRecord {
  final double weight;
  final int reps;

  PersonalRecord(this.weight, this.reps);
}

class ProgressProvider extends ChangeNotifier {
  int streak = 0;
  int totalWorkouts = 0;
  double totalVolume = 0;

  /// Heaviest set per exercise name (ties broken by reps).
  Map<String, PersonalRecord> personalRecords = {};
  List<Workout> recentWorkouts = [];

  /// Start time of every workout.
  List<DateTime> workoutDates = [];

  /// Calendar days (midnight, local) with at least one workout.
  Set<DateTime> workoutDays = {};

  /// Workouts since Monday of the current week.
  int workoutsThisWeek(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return workoutDates.where((d) => !d.isBefore(monday)).length;
  }

  Future<void> loadData() async {
    final repo = WorkoutRepository.instance;
    recentWorkouts = await repo.getRecent(limit: 20);

    final stats = await repo.getStats();
    totalWorkouts = stats.count;
    totalVolume = stats.totalVolume;

    final dates = await repo.getWorkoutDates();
    workoutDates = dates;
    workoutDays = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    streak = calculateStreak(dates, DateTime.now());
    personalRecords = calculatePersonalRecords(await repo.getAllSets());
    notifyListeners();
  }

  /// Consecutive days with a workout, ending today or yesterday.
  static int calculateStreak(List<DateTime> workoutDates, DateTime now) {
    final days = workoutDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }

    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static Map<String, PersonalRecord> calculatePersonalRecords(List<SetRecord> sets) {
    final records = <String, PersonalRecord>{};
    for (final set in sets) {
      final current = records[set.exerciseName];
      if (current == null ||
          set.weight > current.weight ||
          (set.weight == current.weight && set.reps > current.reps)) {
        records[set.exerciseName] = PersonalRecord(set.weight, set.reps);
      }
    }
    return records;
  }
}
