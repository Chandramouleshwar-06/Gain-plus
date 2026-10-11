import 'package:flutter/material.dart';
import '../../data/plan_repository.dart';
import '../../data/program_repository.dart';
import '../../data/programs.dart';
import '../../data/schedule_repository.dart';
import '../../data/seed_data.dart';
import '../../utils/date_keys.dart';
import 'program_scheduler.dart';

/// Your custom programs: building, starting, stopping, and keeping them on
/// track when a session is missed. Callers reload [PlansProvider] after
/// anything that changes the schedule.
class ProgramsProvider extends ChangeNotifier {
  List<CustomProgram> programs = [];

  CustomProgram? byId(String? id) => id == null ? null : programs.where((p) => p.id == id).firstOrNull;

  Future<void> load() async {
    programs = await ProgramRepository.instance.getAll();
    notifyListeners();
  }

  Future<String> save({
    String? id,
    required String name,
    required List<int> weekdays,
    required int weeks,
    required List<String> planIds,
    int? reminderMinutes,
  }) async {
    final savedId = await ProgramRepository.instance.save(
      id: id,
      name: name,
      weekdays: weekdays,
      weeks: weeks,
      planIds: planIds,
      reminderMinutes: reminderMinutes,
    );
    await load();
    return savedId;
  }

  /// Copies a ready-made program into your own: one plan per workout day,
  /// plus a custom program you can edit. Returns the new program's ID.
  /// [swaps] maps exercise names to replacement exercise IDs, for exercises
  /// that need equipment you don't have.
  Future<String> copyBuiltin(Program program, {Map<String, String> swaps = const {}}) async {
    final planIds = <String>[];
    for (final day in program.days) {
      final ids = <String>{};
      planIds.add(await PlanRepository.instance.createWithItems(day.name, [
        for (final e in day.exercises)
          // Skip a swap that would repeat an exercise already in the day.
          if (ids.add(swaps[e.name] ?? builtinExerciseId(e.name))) (swaps[e.name] ?? builtinExerciseId(e.name), e.sets, e.reps),
      ]));
    }
    return save(name: program.name, weekdays: program.defaultWeekdays, weeks: 8, planIds: planIds);
  }

  /// Schedules the program from [from] (default today), replacing any of
  /// its own future days. Returns how many sessions were scheduled.
  Future<int> start(CustomProgram program, {DateTime? from, int? reminderMinutes}) async {
    final today = DateTime.now();
    final start = from ?? DateTime(today.year, today.month, today.day);
    final reminder = reminderMinutes ?? program.reminderMinutes ?? 18 * 60;

    await ScheduleRepository.instance.clearProgram(program.id, from: start);
    final sessions = programSessions(
      start: start,
      weekdays: program.weekdays,
      weeks: program.weeks,
      planIds: program.planIds,
    );
    for (final (date, planId) in sessions) {
      await ScheduleRepository.instance.set(date, planId, reminderMinutes: reminder, programId: program.id);
    }
    await ProgramRepository.instance.setStartedOn(program.id, start, reminderMinutes: reminder);
    await load();
    return sessions.length;
  }

  /// Clears the program's remaining days.
  Future<void> stop(CustomProgram program) async {
    final today = DateTime.now();
    await ScheduleRepository.instance.clearProgram(program.id, from: DateTime(today.year, today.month, today.day));
    await ProgramRepository.instance.setStartedOn(program.id, null);
    await load();
  }

  Future<void> delete(CustomProgram program) async {
    await stop(program);
    await ProgramRepository.instance.delete(program.id);
    await load();
  }

  /// Does a missed session today. In a program, every later session shifts
  /// to the following training days so the order is kept; otherwise just
  /// that day moves to today.
  ///
  /// Program sessions already trained (between the missed day and today)
  /// aren't repeated, and other workouts booked on later days are kept.
  Future<void> doMissedToday(
    MissedSession missed,
    Map<String, ScheduleEntry> schedules, {
    Set<DateTime> trainedDays = const {},
  }) async {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final program = byId(missed.programId);

    // Whatever else was planned for today moves to the next free day.
    Future<void> moveTodayAside() async {
      final existing = schedules[dateKey(todayDay)];
      if (existing == null || (program != null && existing.programId == program.id)) return;
      for (var i = 1; i <= 7; i++) {
        final day = DateTime(todayDay.year, todayDay.month, todayDay.day + i);
        if (!schedules.containsKey(dateKey(day))) {
          await ScheduleRepository.instance.set(day, existing.planId,
              reminderMinutes: existing.reminderMinutes, programId: existing.programId);
          return;
        }
      }
    }

    if (program == null) {
      final reminder = schedules[dateKey(missed.date)]?.reminderMinutes;
      await ScheduleRepository.instance.clear(missed.date);
      await moveTodayAside();
      await ScheduleRepository.instance.set(todayDay, missed.planId, reminderMinutes: reminder);
      return;
    }

    bool trained(DateTime date) => trainedDays.contains(date);
    final later = schedules.values.where((s) {
      final date = parseDateKey(s.date);
      if (s.programId != program.id || date.isBefore(missed.date)) return false;
      // Sessions done since the miss stay where they were.
      return !(date.isBefore(todayDay) && date != missed.date && trained(date));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final sequence = later.map((s) => s.planId).toList();
    final blocked = {
      for (final s in schedules.values)
        if (s.programId != program.id && !parseDateKey(s.date).isBefore(todayDay)) s.date,
    };

    await moveTodayAside();
    // Clear only the sessions that are moving.
    for (final s in later) {
      await ScheduleRepository.instance.clear(parseDateKey(s.date));
    }
    for (final (date, planId)
        in shiftAfterMiss(planSequence: sequence, weekdays: program.weekdays, today: todayDay, blocked: blocked)) {
      await ScheduleRepository.instance.set(date, planId,
          reminderMinutes: program.reminderMinutes, programId: program.id);
    }
  }

  /// Drops a missed session without moving anything.
  Future<void> skipMissed(MissedSession missed) => ScheduleRepository.instance.clear(missed.date);
}
