import 'package:flutter/material.dart';
import '../../data/workout_repository.dart';

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// One week's training, for the recap.
class WeekSummary {
  final DateTime weekStart;
  final int workouts;
  final double volume;
  final double previousWeekVolume;

  /// Exercises where a heavier weight than ever before was lifted this week.
  final List<String> newPrs;

  WeekSummary({
    required this.weekStart,
    required this.workouts,
    required this.volume,
    required this.previousWeekVolume,
    required this.newPrs,
  });

  /// Change in volume vs the week before, as a fraction (0.08 = +8%), or
  /// null when there's nothing to compare against.
  double? get volumeChange => previousWeekVolume == 0 ? null : (volume - previousWeekVolume) / previousWeekVolume;
}

WeekSummary summarizeWeek({
  required DateTime weekStart,
  required List<(DateTime, double)> volumes,
  required List<SetRecord> sets,
}) {
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  final previousStart = DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
  bool inRange(DateTime d, DateTime from, DateTime to) => !d.isBefore(from) && d.isBefore(to);

  var workouts = 0;
  var volume = 0.0;
  var previousVolume = 0.0;
  for (final (date, v) in volumes) {
    if (inRange(date, weekStart, weekEnd)) {
      workouts++;
      volume += v;
    } else if (inRange(date, previousStart, weekStart)) {
      previousVolume += v;
    }
  }

  // A PR counts when this week's heaviest set beats everything before it.
  final bestBefore = <String, double>{};
  final bestThisWeek = <String, double>{};
  final names = <String, String>{};
  for (final s in sets) {
    final date = s.date;
    if (date == null || s.weight <= 0) continue;
    names[s.exerciseId] = s.exerciseName;
    if (date.isBefore(weekStart)) {
      if (s.weight > (bestBefore[s.exerciseId] ?? 0)) bestBefore[s.exerciseId] = s.weight;
    } else if (date.isBefore(weekEnd)) {
      if (s.weight > (bestThisWeek[s.exerciseId] ?? 0)) bestThisWeek[s.exerciseId] = s.weight;
    }
  }
  final newPrs = [
    for (final e in bestThisWeek.entries)
      if (bestBefore.containsKey(e.key) && e.value > bestBefore[e.key]!) names[e.key]!,
  ];

  return WeekSummary(
    weekStart: weekStart,
    workouts: workouts,
    volume: volume,
    previousWeekVolume: previousVolume,
    newPrs: newPrs,
  );
}

/// Longest run of consecutive days with a workout.
int longestStreak(List<DateTime> dates) {
  final days = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in days) {
    final isNext = previous != null && DateTime(previous.year, previous.month, previous.day + 1) == day;
    run = isNext ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// (weeks where the target was hit, longest run of such weeks in a row).
(int, int) targetWeeks(List<DateTime> dates, int target) {
  final perWeek = <DateTime, int>{};
  for (final d in dates) {
    final week = mondayOf(d);
    perWeek[week] = (perWeek[week] ?? 0) + 1;
  }
  final hitWeeks = perWeek.entries.where((e) => e.value >= target).map((e) => e.key).toList()..sort();
  var bestRun = 0;
  var run = 0;
  DateTime? previous;
  for (final week in hitWeeks) {
    final isNext = previous != null && DateTime(previous.year, previous.month, previous.day + 7) == week;
    run = isNext ? run + 1 : 1;
    if (run > bestRun) bestRun = run;
    previous = week;
  }
  return (hitWeeks.length, bestRun);
}

class AchievementStats {
  final int totalWorkouts;
  final int longestStreak;
  final int targetWeeks;
  final int bestTargetRun;
  final double totalVolumeKg;
  final int goalsAchieved;

  const AchievementStats({
    this.totalWorkouts = 0,
    this.longestStreak = 0,
    this.targetWeeks = 0,
    this.bestTargetRun = 0,
    this.totalVolumeKg = 0,
    this.goalsAchieved = 0,
  });
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final double target;
  final double Function(AchievementStats) measure;

  const Achievement(this.id, this.title, this.description, this.icon, this.target, this.measure);

  double progress(AchievementStats stats) => (measure(stats) / target).clamp(0.0, 1.0);
  bool isUnlocked(AchievementStats stats) => measure(stats) >= target;
}

final achievements = <Achievement>[
  Achievement('workouts-1', 'First rep', 'Finish your first workout', Icons.flag_rounded, 1, (s) => s.totalWorkouts.toDouble()),
  Achievement('workouts-10', 'Getting serious', 'Finish 10 workouts', Icons.fitness_center_rounded, 10, (s) => s.totalWorkouts.toDouble()),
  Achievement('workouts-25', 'Regular', 'Finish 25 workouts', Icons.repeat_rounded, 25, (s) => s.totalWorkouts.toDouble()),
  Achievement('workouts-50', 'Committed', 'Finish 50 workouts', Icons.workspace_premium_rounded, 50, (s) => s.totalWorkouts.toDouble()),
  Achievement('workouts-100', 'Centurion', 'Finish 100 workouts', Icons.military_tech_rounded, 100, (s) => s.totalWorkouts.toDouble()),
  Achievement('streak-3', 'On a roll', 'Train 3 days in a row', Icons.local_fire_department_rounded, 3, (s) => s.longestStreak.toDouble()),
  Achievement('streak-7', 'Week warrior', 'Train 7 days in a row', Icons.whatshot_rounded, 7, (s) => s.longestStreak.toDouble()),
  Achievement('target-1', 'Target hit', 'Hit your weekly target', Icons.track_changes_rounded, 1, (s) => s.targetWeeks.toDouble()),
  Achievement('target-run-4', 'Consistency', 'Hit your weekly target 4 weeks in a row', Icons.calendar_month_rounded, 4, (s) => s.bestTargetRun.toDouble()),
  Achievement('volume-10t', '10 tonne club', 'Lift 10,000 kg in total', Icons.trending_up_rounded, 10000, (s) => s.totalVolumeKg),
  Achievement('volume-100t', '100 tonne club', 'Lift 100,000 kg in total', Icons.rocket_launch_rounded, 100000, (s) => s.totalVolumeKg),
  Achievement('goal-1', 'Goal getter', 'Reach one of your goals', Icons.emoji_events_rounded, 1, (s) => s.goalsAchieved.toDouble()),
];
