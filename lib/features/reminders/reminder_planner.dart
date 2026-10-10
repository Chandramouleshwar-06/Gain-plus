import 'dart:math';

/// Kinds of reminder. The code is part of the notification ID, so it must
/// stay stable (1-9).
enum ReminderKind {
  workout(1),
  followUp(2),
  streak(3),
  weeklyGoal(4),
  inactivity(5),
  recap(6);

  const ReminderKind(this.code);
  final int code;
}

class ReminderPrefs {
  final bool workout;
  final bool followUp;
  final bool streak;
  final bool weeklyGoal;
  final bool inactivity;
  final bool recap;

  /// No reminders (other than ones you set a time for) from [quietStartHour]
  /// until [quietEndHour].
  final int quietStartHour;
  final int quietEndHour;

  /// Most notifications on any one day.
  final int dailyCap;

  const ReminderPrefs({
    this.workout = true,
    this.followUp = true,
    this.streak = true,
    this.weeklyGoal = true,
    this.inactivity = true,
    this.recap = true,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
    this.dailyCap = 2,
  });
}

class ScheduledDay {
  final DateTime date;
  final String planName;

  /// Reminder time as minutes after midnight, or null for no reminder.
  final int? reminderMinutes;

  ScheduledDay(this.date, this.planName, this.reminderMinutes);
}

class ReminderInput {
  final DateTime now;
  final List<DateTime> workoutDates;
  final int weeklyTarget;
  final List<ScheduledDay> schedule;
  final ReminderPrefs prefs;

  /// This week's recap line, e.g. "4 workouts · 12.4 t lifted · 2 PRs".
  final String thisWeekRecap;

  ReminderInput({
    required this.now,
    required this.workoutDates,
    required this.weeklyTarget,
    required this.schedule,
    required this.prefs,
    required this.thisWeekRecap,
  });
}

class PlannedReminder {
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  PlannedReminder(this.kind, this.at, this.title, this.body);

  /// One per kind per day: kind code, then yymmdd.
  int get id => kind.code * 1000000 + (at.year % 100) * 10000 + at.month * 100 + at.day;

  @override
  String toString() => '$kind @ $at: $title / $body';
}

/// How far ahead to plan. Reminders are re-planned whenever data changes,
/// and workouts can only be logged in the app, so this stays accurate.
const planningDays = 14;

/// Works out every notification for the next [planningDays] days.
List<PlannedReminder> planReminders(ReminderInput input) {
  final now = input.now;
  final today = DateTime(now.year, now.month, now.day);
  final prefs = input.prefs;
  final trainedDays = input.workoutDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
  DateTime at(DateTime d, int hour, [int minute = 0]) => DateTime(d.year, d.month, d.day, hour, minute);

  final candidates = <PlannedReminder>[];
  final scheduledDays = <DateTime>{};

  // Workouts you scheduled, plus a follow-up if you haven't trained by then.
  for (final s in input.schedule) {
    final date = DateTime(s.date.year, s.date.month, s.date.day);
    if (date.isBefore(today) || date.isAfter(day(planningDays)) || trainedDays.contains(date)) continue;
    scheduledDays.add(date);
    final minutes = s.reminderMinutes;
    if (minutes == null) continue;
    final time = at(date, minutes ~/ 60, minutes % 60);
    if (prefs.workout) {
      candidates.add(PlannedReminder(ReminderKind.workout, time, 'Workout time: ${s.planName}', workoutMessage(s.planName)));
    }
    final followUp = time.add(const Duration(hours: 2));
    if (prefs.followUp && followUp.day == time.day) {
      candidates.add(PlannedReminder(
        ReminderKind.followUp,
        followUp,
        '${s.planName} is still on for today',
        "There's still time. Even a shorter session counts.",
      ));
    }
  }

  final sortedDates = [...trainedDays]..sort();
  final lastWorkout = sortedDates.isEmpty ? null : sortedDates.last;

  // Streak about to break: trained yesterday (and before), not yet today.
  if (prefs.streak && lastWorkout == day(-1)) {
    var streak = 0;
    var d = lastWorkout!;
    while (trainedDays.contains(d)) {
      streak++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    if (streak >= 2) {
      candidates.add(PlannedReminder(
        ReminderKind.streak,
        at(today, 19),
        'Your $streak-day streak ends tonight',
        'A quick session keeps it going.',
      ));
    }
  }

  // Weekly target check-ins: Thursday evening and Saturday morning.
  if (prefs.weeklyGoal && input.weeklyTarget > 0) {
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    for (var week = 0; week < 2; week++) {
      final weekStart = DateTime(monday.year, monday.month, monday.day + 7 * week);
      final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
      final done = trainedDays.where((d) => !d.isBefore(weekStart) && d.isBefore(weekEnd)).length;
      final remaining = input.weeklyTarget - done;
      if (remaining <= 0) continue;
      for (final (weekday, hour) in [(4, 18), (6, 10)]) {
        final date = DateTime(weekStart.year, weekStart.month, weekStart.day + weekday - 1);
        final daysLeft = 8 - weekday;
        candidates.add(PlannedReminder(
          ReminderKind.weeklyGoal,
          at(date, hour),
          '$done of ${input.weeklyTarget} workouts this week',
          remaining > daysLeft
              ? "The target's out of reach this week, but every session still counts."
              : '$remaining to go with $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left. You can do this.',
        ));
      }
    }
  }

  // Inactivity nudges, gentler as time goes on.
  if (prefs.inactivity) {
    final nudges = lastWorkout == null
        ? [(1, 'Ready for your first workout?', 'Pick a plan and start. The first one is the hardest.')]
        : [
            (3, "It's been 3 days", 'Your muscles have recovered. Time to train.'),
            (5, 'Missing you at the gym', 'Even 20 minutes is better than nothing.'),
            (8, "Let's get back on track", 'Start light. Showing up is what matters.'),
            (14, 'Your plans are waiting', 'Whenever you are ready, one workout restarts the habit.'),
          ];
    final base = lastWorkout ?? today;
    for (final (afterDays, title, body) in nudges) {
      final date = DateTime(base.year, base.month, base.day + afterDays);
      if (scheduledDays.contains(date)) continue; // a workout reminder already covers it
      candidates.add(PlannedReminder(ReminderKind.inactivity, at(date, 18), title, body));
    }
  }

  // Sunday evening recap of this week.
  if (prefs.recap) {
    final sunday = DateTime(today.year, today.month, today.day + (7 - today.weekday));
    candidates.add(PlannedReminder(ReminderKind.recap, at(sunday, 19), 'Your week in review', input.thisWeekRecap));
  }

  return _applyRules(candidates, now, prefs);
}

List<PlannedReminder> _applyRules(List<PlannedReminder> candidates, DateTime now, ReminderPrefs prefs) {
  bool inQuietHours(DateTime t) {
    final h = t.hour;
    return prefs.quietStartHour > prefs.quietEndHour
        ? h >= prefs.quietStartHour || h < prefs.quietEndHour
        : h >= prefs.quietStartHour && h < prefs.quietEndHour;
  }

  // Lower number wins when a day is over the cap.
  int priority(ReminderKind kind) => switch (kind) {
        ReminderKind.workout => 0,
        ReminderKind.streak => 1,
        ReminderKind.recap => 2,
        ReminderKind.followUp => 3,
        ReminderKind.weeklyGoal => 4,
        ReminderKind.inactivity => 5,
      };

  final upcoming = candidates.where((r) => r.at.isAfter(now)).where((r) {
    // A time you picked yourself is always kept.
    return r.kind == ReminderKind.workout || !inQuietHours(r.at);
  });

  final byDay = <DateTime, List<PlannedReminder>>{};
  for (final r in upcoming) {
    byDay.putIfAbsent(DateTime(r.at.year, r.at.month, r.at.day), () => []).add(r);
  }

  final result = <PlannedReminder>[];
  for (final dayReminders in byDay.values) {
    dayReminders.sort((a, b) => priority(a.kind).compareTo(priority(b.kind)));
    final cap = max(prefs.dailyCap, dayReminders.where((r) => r.kind == ReminderKind.workout).length);
    result.addAll(dayReminders.take(cap));
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

/// A motivating line that fits the plan.
String workoutMessage(String planName) {
  final name = planName.toLowerCase();
  final random = Random(planName.hashCode ^ DateTime.now().day);
  String pick(List<String> options) => options[random.nextInt(options.length)];

  if (name.contains('leg') || name.contains('lower')) {
    return pick([
      'No more chicken legs, go train!',
      "Friends don't let friends skip leg day.",
      'The squats are calling and I must go.',
    ]);
  }
  if (name.contains('chest') || name.contains('push') || name.contains('upper')) {
    return pick(['Time to build that armor plating.', 'International Chest Day is every day.', 'Bench more, worry less.']);
  }
  if (name.contains('back') || name.contains('pull')) {
    return pick(['Wings are made in the gym, not at KFC.', 'Building a back like a cobra.', 'Pull day = Best day.']);
  }
  return pick([
    'Your workout is waiting for you!',
    "Don't wish for it, work for it.",
    'The only bad workout is the one that didn\'t happen.',
  ]);
}
