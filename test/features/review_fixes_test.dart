import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/activity_types.dart';
import 'package:gain_plus/data/muscles.dart';
import 'package:gain_plus/features/health/health_import.dart';
import 'package:gain_plus/features/plans/program_scheduler.dart';
import 'package:gain_plus/features/profile/profile_provider.dart';
import 'package:gain_plus/features/progress/muscle_analysis.dart';
import 'package:gain_plus/features/reminders/reminder_planner.dart';
import 'package:gain_plus/models/profile.dart';
import 'package:gain_plus/services/health_service.dart';
import 'package:gain_plus/utils/date_keys.dart';
import 'package:gain_plus/utils/format.dart';

void main() {
  test('typed numbers: comma decimals and thousands groups', () {
    expect(parseDecimal('82,5'), 82.5);
    expect(parseDecimal('82.5'), 82.5);
    expect(parseDecimal('1,200'), 1200);
    expect(parseDecimal('12,500.5'), 12500.5);
    expect(parseDecimal(' 70 '), 70);
    expect(parseDecimal('abc'), isNull);
  });

  test('a lift goal set below your best is done once you lift it', () {
    final goal = Goal(id: 'g', type: Goal.typeLift, exerciseId: 'e', targetValue: 90, startValue: 100);
    expect(ProfileProvider.goalProgress(goal, 100), 1);
  });

  test('catch-up shift skips days booked with other workouts', () {
    final today = DateTime(2026, 10, 12); // Monday
    final result = shiftAfterMiss(
      planSequence: ['A', 'B', 'C'],
      weekdays: [1, 3, 5],
      today: today,
      blocked: {dateKey(DateTime(2026, 10, 14))}, // Wednesday is taken
    );
    expect(result.map((r) => '${dateKey(r.$1)} ${r.$2}'), ['2026-10-12 A', '2026-10-16 B', '2026-10-19 C']);
  });

  test('imported workout calories are capped at twice the estimate', () {
    final start = DateTime(2026, 10, 1, 7);
    final activities = activitiesFromHealth(
      [
        HealthWorkoutRecord(
            id: 'w', type: 'WALKING', start: start, end: start.add(const Duration(minutes: 30)), kcal: 2000),
      ],
      alreadyImported: {},
      body: const BodyMetrics(weightKg: 60),
      idFor: (r) => r.id,
    );
    // 3.5 METs x 60 kcal/h x 0.5 h = 105, so at most 210.
    expect(activities.single.kcal, 210);
  });

  test('weekly reminder counts workouts, not training days', () {
    final monday = DateTime(2026, 10, 12);
    final plan = planReminders(ReminderInput(
      now: DateTime(2026, 10, 15, 9), // Thursday morning
      workoutDates: [
        DateTime(2026, 10, 13, 7),
        DateTime(2026, 10, 13, 18), // two on Tuesday
        DateTime(2026, 10, 14, 7),
      ],
      weeklyTarget: 3,
      schedule: const [],
      prefs: const ReminderPrefs(),
      thisWeekRecap: '',
    ));
    final weekly = plan.where((r) => r.kind == ReminderKind.weeklyGoal && !r.at.isBefore(monday)).toList();
    expect(weekly.where((r) => r.at.isBefore(DateTime(2026, 10, 19))), isEmpty, reason: 'target already hit');
  });

  test('recovery ready times come out for muscles still recovering', () {
    final now = DateTime(2026, 10, 11, 18);
    final sets = [
      for (var i = 0; i < 6; i++) MuscleSet(now.subtract(const Duration(hours: 1)), ([Muscle.quads], const [])),
    ];
    final hours = hoursUntilReady(sets, now);
    expect(hours[Muscle.quads], inInclusiveRange(40, 72));
    expect(hours.containsKey(Muscle.chest), isFalse);
  });
}
