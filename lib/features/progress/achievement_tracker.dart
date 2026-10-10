import 'package:shared_preferences/shared_preferences.dart';
import '../../models/profile.dart';
import '../profile/profile_provider.dart';
import 'insights.dart';
import 'progress_provider.dart';

/// Builds the numbers achievements are measured against.
AchievementStats achievementStats(ProgressProvider progress, ProfileProvider profile) {
  final (weeks, run) = targetWeeks(progress.workoutDates, profile.weeklyTarget);
  return AchievementStats(
    totalWorkouts: progress.totalWorkouts,
    longestStreak: progress.longestStreakDays,
    targetWeeks: weeks,
    bestTargetRun: run,
    totalVolumeKg: progress.totalVolume,
    goalsAchieved: profile.goals.where((Goal g) => g.achievedAt != null).length,
  );
}

/// Remembers which achievements were already celebrated on this device.
class AchievementTracker {
  static final AchievementTracker instance = AchievementTracker._();
  AchievementTracker._();

  static const _key = 'achievements_seen';

  /// Achievements unlocked since the last check. The very first check only
  /// records what's already unlocked, so existing users aren't flooded.
  Future<List<Achievement>> checkNew(AchievementStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key);
    final unlocked = achievements.where((a) => a.isUnlocked(stats)).toList();
    await prefs.setStringList(_key, {...?seen, ...unlocked.map((a) => a.id)}.toList());
    if (seen == null) return [];
    return unlocked.where((a) => !seen.contains(a.id)).toList();
  }
}
