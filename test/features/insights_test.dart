import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/features/progress/achievement_tracker.dart';
import 'package:gain_plus/features/progress/insights.dart';
import 'package:gain_plus/features/reminders/reminder_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final monday = DateTime(2026, 10, 5);

  test('week summary counts workouts, compares volume and finds new PRs', () {
    final week = summarizeWeek(
      weekStart: monday,
      volumes: [
        (DateTime(2026, 10, 5, 18), 6000),
        (DateTime(2026, 10, 7, 18), 6000),
        (DateTime(2026, 9, 30, 18), 10000), // last week
      ],
      sets: [
        SetRecord('bench', 'Bench', 80, 5, DateTime(2026, 9, 30)),
        SetRecord('bench', 'Bench', 85, 5, DateTime(2026, 10, 5)), // new PR
        SetRecord('squat', 'Squat', 100, 5, DateTime(2026, 9, 30)),
        SetRecord('squat', 'Squat', 100, 6, DateTime(2026, 10, 7)), // same weight: not a PR
        SetRecord('curl', 'Curl', 20, 10, DateTime(2026, 10, 7)), // first time: not a PR
      ],
    );
    expect(week.workouts, 2);
    expect(week.volume, 12000);
    expect(week.volumeChange, closeTo(0.2, 1e-9));
    expect(week.newPrs, ['Bench']);
    expect(recapLine(week), '2 workouts · 12.0 t lifted · 1 PR');
  });

  test('longest streak and weeks the target was hit', () {
    final dates = [
      DateTime(2026, 9, 1), DateTime(2026, 9, 2), DateTime(2026, 9, 3), // 3-day run
      DateTime(2026, 9, 10),
      DateTime(2026, 9, 15), DateTime(2026, 9, 17),
      DateTime(2026, 9, 22), DateTime(2026, 9, 24),
    ];
    expect(longestStreak(dates), 3);
    // Weeks of 31 Aug (3), 7 Sep (1), 14 Sep (2), 21 Sep (2); target 2.
    expect(targetWeeks(dates, 2), (3, 2));
  });

  test('achievements unlock once; the first check only sets a baseline', () async {
    SharedPreferences.setMockInitialValues({});
    const none = AchievementStats();
    const one = AchievementStats(totalWorkouts: 1);
    const eleven = AchievementStats(totalWorkouts: 11, totalVolumeKg: 12000);

    expect(await AchievementTracker.instance.checkNew(none), isEmpty, reason: 'baseline');
    expect((await AchievementTracker.instance.checkNew(one)).map((a) => a.id), ['workouts-1']);
    expect(await AchievementTracker.instance.checkNew(one), isEmpty, reason: 'only celebrated once');
    expect((await AchievementTracker.instance.checkNew(eleven)).map((a) => a.id), ['workouts-10', 'volume-10t']);
  });
}
