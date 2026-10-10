import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/reminders/reminder_planner.dart';

void main() {
  // Tuesday 6 Oct 2026, 09:00.
  final now = DateTime(2026, 10, 6, 9);

  List<PlannedReminder> plan({
    List<DateTime> workouts = const [],
    List<ScheduledDay> schedule = const [],
    ReminderPrefs prefs = const ReminderPrefs(),
    int target = 3,
  }) =>
      planReminders(ReminderInput(
        now: now,
        workoutDates: workouts,
        weeklyTarget: target,
        schedule: schedule,
        prefs: prefs,
        thisWeekRecap: '1 workout',
      ));

  Iterable<PlannedReminder> ofKind(List<PlannedReminder> r, ReminderKind k) => r.where((x) => x.kind == k);

  test('scheduled workout gets a reminder and a follow-up two hours later', () {
    final r = plan(schedule: [ScheduledDay(DateTime(2026, 10, 7), 'Push Day', 18 * 60)]);
    expect(ofKind(r, ReminderKind.workout).single.at, DateTime(2026, 10, 7, 18));
    expect(ofKind(r, ReminderKind.followUp).single.at, DateTime(2026, 10, 7, 20));
  });

  test('no reminder or follow-up for a day already trained', () {
    final r = plan(
      workouts: [DateTime(2026, 10, 6, 7)],
      schedule: [ScheduledDay(DateTime(2026, 10, 6), 'Push Day', 18 * 60)],
    );
    expect(ofKind(r, ReminderKind.workout), isEmpty);
    expect(ofKind(r, ReminderKind.followUp), isEmpty);
  });

  test('streak alert tonight when trained the last two days but not today', () {
    final r = plan(workouts: [DateTime(2026, 10, 4), DateTime(2026, 10, 5)]);
    final streak = ofKind(r, ReminderKind.streak).single;
    expect(streak.at, DateTime(2026, 10, 6, 19));
    expect(streak.title, contains('2-day streak'));

    expect(ofKind(plan(workouts: [DateTime(2026, 10, 5)]), ReminderKind.streak), isEmpty,
        reason: 'a one-day streak is not worth an alert');
  });

  test('inactivity nudges count from the last workout and skip scheduled days', () {
    final r = plan(
      workouts: [DateTime(2026, 10, 2)],
      schedule: [ScheduledDay(DateTime(2026, 10, 7), 'Legs', null)], // day 5, no reminder time
      prefs: const ReminderPrefs(streak: false, weeklyGoal: false, recap: false),
    );
    final days = ofKind(r, ReminderKind.inactivity).map((x) => x.at.day).toList();
    // Day 3 (5 Oct) is past; day 5 (7 Oct) is a scheduled day; day 8 and 14 remain.
    expect(days, [10, 16]);
  });

  test('weekly check-ins report progress against the target', () {
    final r = plan(workouts: [DateTime(2026, 10, 5)], target: 3);
    final thursday = ofKind(r, ReminderKind.weeklyGoal).firstWhere((x) => x.at.day == 8);
    expect(thursday.title, '1 of 3 workouts this week');
    expect(thursday.body, contains('2 to go'));
  });

  test('daily cap keeps the most important reminders; your own times always stay', () {
    // Thursday 8 Oct: workout reminder, its follow-up and a weekly check-in.
    final r = plan(
      schedule: [ScheduledDay(DateTime(2026, 10, 8), 'Push Day', 17 * 60)],
      prefs: const ReminderPrefs(dailyCap: 1),
    );
    final thursday = r.where((x) => x.at.day == 8).toList();
    expect(thursday.map((x) => x.kind), [ReminderKind.workout]);
  });

  test('quiet hours drop automatic reminders but not times you picked', () {
    final r = plan(
      schedule: [ScheduledDay(DateTime(2026, 10, 7), 'Late Session', 23 * 60)],
      prefs: const ReminderPrefs(quietStartHour: 21, quietEndHour: 8),
    );
    expect(ofKind(r, ReminderKind.workout).single.at.hour, 23);
    expect(r.where((x) => x.kind != ReminderKind.workout).every((x) => x.at.hour >= 8 && x.at.hour < 21), isTrue);
  });

  test('turned-off kinds are never planned and IDs are unique', () {
    final r = plan(
      workouts: [DateTime(2026, 10, 4), DateTime(2026, 10, 5)],
      prefs: const ReminderPrefs(streak: false, recap: false, dailyCap: 4),
    );
    expect(ofKind(r, ReminderKind.streak), isEmpty);
    expect(ofKind(r, ReminderKind.recap), isEmpty);
    expect(r.map((x) => x.id).toSet().length, r.length);
    expect(r.every((x) => x.at.isAfter(now)), isTrue);
  });

  test('Sunday recap carries the summary line', () {
    final recap = ofKind(plan(), ReminderKind.recap).single;
    expect(recap.at, DateTime(2026, 10, 11, 19));
    expect(recap.body, '1 workout');
  });
}
