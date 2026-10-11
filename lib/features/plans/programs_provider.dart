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
  Future<String> copyBuiltin(Program program) async {
    final planIds = <String>[];
    for (final day in program.days) {
      planIds.add(await PlanRepository.instance.createWithItems(day.name, [
        for (final e in day.exercises) (builtinExerciseId(e.name), e.sets, e.reps),
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
  Future<void> doMissedToday(MissedSession missed, Map<String, ScheduleEntry> schedules) async {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final program = byId(missed.programId);

    if (program == null) {
      final reminder = schedules[dateKey(missed.date)]?.reminderMinutes;
      await ScheduleRepository.instance.clear(missed.date);
      // Whatever was planned for today moves to the next free day.
      final existing = schedules[dateKey(todayDay)];
      if (existing != null) {
        for (var i = 1; i <= 7; i++) {
          final day = DateTime(todayDay.year, todayDay.month, todayDay.day + i);
          if (!schedules.containsKey(dateKey(day))) {
            await ScheduleRepository.instance.set(day, existing.planId,
                reminderMinutes: existing.reminderMinutes, programId: existing.programId);
            break;
          }
        }
      }
      await ScheduleRepository.instance.set(todayDay, missed.planId, reminderMinutes: reminder);
      return;
    }

    final later = schedules.values
        .where((s) => s.programId == program.id && !parseDateKey(s.date).isBefore(missed.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final sequence = later.map((s) => s.planId).toList();

    await ScheduleRepository.instance.clearProgram(program.id, from: missed.date);
    for (final (date, planId) in shiftAfterMiss(planSequence: sequence, weekdays: program.weekdays, today: todayDay)) {
      await ScheduleRepository.instance.set(date, planId,
          reminderMinutes: program.reminderMinutes, programId: program.id);
    }
  }

  /// Drops a missed session without moving anything.
  Future<void> skipMissed(MissedSession missed) => ScheduleRepository.instance.clear(missed.date);
}
