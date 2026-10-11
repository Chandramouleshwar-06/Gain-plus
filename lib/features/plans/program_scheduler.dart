import '../../utils/date_keys.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The program's sessions: workouts rotate in order through the training
/// [weekdays] (1 = Monday) for [weeks] weeks, starting on [start].
List<(DateTime, String)> programSessions({
  required DateTime start,
  required List<int> weekdays,
  required int weeks,
  required List<String> planIds,
}) {
  if (weekdays.isEmpty || planIds.isEmpty) return [];
  final first = _day(start);
  final sessions = <(DateTime, String)>[];
  for (var offset = 0; offset < weeks * 7; offset++) {
    final date = DateTime(first.year, first.month, first.day + offset);
    if (weekdays.contains(date.weekday)) {
      sessions.add((date, planIds[sessions.length % planIds.length]));
    }
  }
  return sessions;
}

/// After a missed session, keeps the workouts in order: the missed workout
/// moves to [today] and every later one moves to the following training
/// days. [planSequence] is the missed plan followed by the rest, in order.
List<(DateTime, String)> shiftAfterMiss({
  required List<String> planSequence,
  required List<int> weekdays,
  required DateTime today,
}) {
  if (planSequence.isEmpty) return [];
  final start = _day(today);
  final result = <(DateTime, String)>[(start, planSequence.first)];
  var offset = 1;
  while (result.length < planSequence.length && weekdays.isNotEmpty) {
    final date = DateTime(start.year, start.month, start.day + offset++);
    if (weekdays.contains(date.weekday)) result.add((date, planSequence[result.length]));
  }
  return result;
}

class MissedSession {
  final DateTime date;
  final String planId;
  final String? programId;

  MissedSession(this.date, this.planId, this.programId);
}

/// The earliest scheduled day in the last [lookbackDays] days (before
/// today) with no workout logged, or null if nothing was missed.
MissedSession? findMissed({
  required Iterable<(String dateKey, String planId, String? programId)> schedules,
  required Set<DateTime> trainedDays,
  required DateTime today,
  int lookbackDays = 7,
}) {
  final todayDay = _day(today);
  final earliest = DateTime(todayDay.year, todayDay.month, todayDay.day - lookbackDays);
  MissedSession? missed;
  for (final (key, planId, programId) in schedules) {
    final date = parseDateKey(key);
    if (!date.isBefore(todayDay) || date.isBefore(earliest) || trainedDays.contains(date)) continue;
    if (missed == null || date.isBefore(missed.date)) missed = MissedSession(date, planId, programId);
  }
  return missed;
}
