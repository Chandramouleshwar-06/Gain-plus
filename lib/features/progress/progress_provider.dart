import 'package:flutter/material.dart';
import '../../data/workout_repository.dart';
import '../../models/workout.dart';
import '../../utils/strength.dart';

class LiftSummary {
  final String exerciseId;
  final String name;
  final double prWeight;
  final int prReps;
  final double bestE1rm;

  LiftSummary(this.exerciseId, this.name, this.prWeight, this.prReps, this.bestE1rm);
}

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

  /// Per-exercise bests, strongest first.
  List<LiftSummary> lifts = [];

  /// Volume per week for the last 8 weeks, oldest first.
  List<(DateTime, double)> weeklyVolume = [];

  /// Heaviest weight lifted per exercise ID, for goals.
  Map<String, double> prKgByExerciseId = {};
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
    weeklyVolume = calculateWeeklyVolume(await repo.getVolumes(), DateTime.now());
    final sets = await repo.getAllSets();
    lifts = calculateLiftSummaries(sets);
    personalRecords = calculatePersonalRecords(sets);
    prKgByExerciseId = {};
    for (final set in sets) {
      final best = prKgByExerciseId[set.exerciseId];
      if (best == null || set.weight > best) prKgByExerciseId[set.exerciseId] = set.weight;
    }
    notifyListeners();
  }

  /// Volume per week (Monday start) for the last [weeks] weeks, oldest first.
  static List<(DateTime, double)> calculateWeeklyVolume(List<(DateTime, double)> volumes, DateTime now,
      {int weeks = 8}) {
    final thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final starts = [for (var i = weeks - 1; i >= 0; i--) DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * i)];
    final totals = List<double>.filled(weeks, 0);
    for (final (date, volume) in volumes) {
      final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
      // Rounded so a daylight-saving shift doesn't land in the wrong week.
      final index = (monday.difference(starts.first).inHours / (24 * 7)).round();
      if (index >= 0 && index < weeks) totals[index] += volume;
    }
    return [for (var i = 0; i < weeks; i++) (starts[i], totals[i])];
  }

  /// Best set and best estimated 1RM per exercise, strongest first.
  static List<LiftSummary> calculateLiftSummaries(List<SetRecord> sets) {
    final byId = <String, LiftSummary>{};
    for (final s in sets) {
      final e1rm = estimateOneRepMax(s.weight, s.reps);
      final current = byId[s.exerciseId];
      if (current == null) {
        byId[s.exerciseId] = LiftSummary(s.exerciseId, s.exerciseName, s.weight, s.reps, e1rm);
        continue;
      }
      final heavier = s.weight > current.prWeight || (s.weight == current.prWeight && s.reps > current.prReps);
      byId[s.exerciseId] = LiftSummary(
        s.exerciseId,
        current.name,
        heavier ? s.weight : current.prWeight,
        heavier ? s.reps : current.prReps,
        e1rm > current.bestE1rm ? e1rm : current.bestE1rm,
      );
    }
    return byId.values.toList()..sort((a, b) => b.bestE1rm.compareTo(a.bestE1rm));
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
