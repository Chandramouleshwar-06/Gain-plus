import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/plans/plans_provider.dart';
import 'package:gain_plus/features/plans/program_scheduler.dart';
import 'package:gain_plus/features/plans/programs_provider.dart';
import 'package:gain_plus/utils/date_keys.dart';

import '../helpers/test_db.dart';

void main() {
  test('sessions rotate workouts through the training days', () {
    final s = programSessions(start: DateTime(2026, 10, 5), weekdays: [1, 3, 5], weeks: 1, planIds: ['A', 'B']);
    expect(s.map((x) => (x.$1.day, x.$2)), [(5, 'A'), (7, 'B'), (9, 'A')]);
  });

  test('after a miss the missed workout is today and the rest follow on training days', () {
    // Today is Wednesday 7 Oct; training Mon/Wed/Fri.
    final shifted = shiftAfterMiss(planSequence: ['A', 'B', 'C'], weekdays: [1, 3, 5], today: DateTime(2026, 10, 7, 15));
    expect(shifted.map((x) => (x.$1, x.$2)), [
      (DateTime(2026, 10, 7), 'A'),
      (DateTime(2026, 10, 9), 'B'),
      (DateTime(2026, 10, 12), 'C'),
    ]);

    // On a rest day (Tuesday) the missed one still moves to today.
    final fromTuesday = shiftAfterMiss(planSequence: ['A', 'B'], weekdays: [1, 3, 5], today: DateTime(2026, 10, 6));
    expect(fromTuesday.map((x) => x.$1.day), [6, 7]);
  });

  test('missed = scheduled in the last week, before today, with no workout that day', () {
    final today = DateTime(2026, 10, 10);
    final schedules = [
      ('2026-10-01', 'old', null), // too long ago
      ('2026-10-05', 'trained', null), // trained that day
      ('2026-10-07', 'missed', 'p1'),
      ('2026-10-08', 'later-missed', 'p1'),
      ('2026-10-10', 'today', null), // today isn't missed yet
    ];
    final missed = findMissed(
      schedules: schedules,
      trainedDays: {DateTime(2026, 10, 5)},
      today: today,
    )!;
    expect(missed.planId, 'missed');
    expect(missed.date, DateTime(2026, 10, 7));
    expect(missed.programId, 'p1');

    expect(findMissed(schedules: [('2026-10-09', 'x', null)], trainedDays: {DateTime(2026, 10, 9)}, today: today),
        isNull);
  });

  group('with a database', () {
    setUpAll(useFfiDatabase);
    setUp(resetDatabase);

    test('doing a missed program session today shifts the rest of the program', () async {
      final plans = PlansProvider();
      final programs = ProgramsProvider();
      await plans.loadPlans();
      final planIds = plans.plans.take(3).map((p) => p.id).toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final everyDay = [1, 2, 3, 4, 5, 6, 7];

      final id = await programs.save(name: 'Daily', weekdays: everyDay, weeks: 1, planIds: planIds);
      // Started three days ago; nothing was done.
      await programs.start(programs.byId(id)!, from: today.subtract(const Duration(days: 3)));
      await plans.loadPlans();

      final missed = findMissed(
        schedules: plans.schedules.values.map((s) => (s.date, s.planId, s.programId)),
        trainedDays: {},
        today: today,
      )!;
      expect(missed.date, today.subtract(const Duration(days: 3)));

      await programs.doMissedToday(missed, plans.schedules);
      await plans.loadPlans();
      final entries = plans.schedules.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      expect(parseDateKey(entries.first.date), today, reason: 'nothing left in the past');
      expect(entries.first.planId, planIds[0], reason: 'the missed workout comes first');
      expect(entries.map((e) => e.planId).take(3), [planIds[0], planIds[1], planIds[2]]);
      expect(entries.length, 7, reason: 'no sessions lost, just moved');
    });

    test('stopping a program clears its future days but keeps others', () async {
      final plans = PlansProvider();
      final programs = ProgramsProvider();
      await plans.loadPlans();
      final planId = plans.plans.first.id;
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      await plans.scheduleWorkout(DateTime(now.year, now.month, now.day + 10), planId, const TimeOfDay(hour: 9, minute: 0));
      final id = await programs.save(name: 'P', weekdays: [tomorrow.weekday], weeks: 1, planIds: [planId]);
      await programs.start(programs.byId(id)!, from: tomorrow);
      await plans.loadPlans();
      expect(plans.schedules.length, 2);

      await programs.stop(programs.byId(id)!);
      await plans.loadPlans();
      expect(plans.schedules.values.single.programId, isNull);
      expect(programs.byId(id)!.isActive, isFalse);
    });
  });
}
