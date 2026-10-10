import 'package:flutter/material.dart';
import '../../data/plan_repository.dart';
import '../../data/programs.dart';
import '../../data/seed_data.dart';
import '../../data/schedule_repository.dart';
import '../../models/workout_plan.dart';
import '../../services/notification_service.dart';
import '../../utils/date_keys.dart';

class PlansProvider extends ChangeNotifier {
  List<WorkoutPlan> plans = [];

  /// Scheduled plans keyed by [dateKey].
  Map<String, ScheduleEntry> schedules = {};

  Future<void> loadPlans() async {
    plans = await PlanRepository.instance.getAll();
    schedules = await ScheduleRepository.instance.getAll();
    notifyListeners();
  }

  WorkoutPlan? planById(String id) => plans.where((p) => p.id == id).firstOrNull;

  /// The plan scheduled for [date], if any.
  WorkoutPlan? planForDate(DateTime date) {
    final entry = schedules[dateKey(date)];
    return entry == null ? null : planById(entry.planId);
  }

  /// Creates an empty plan and returns its ID.
  Future<String> createPlan(String name) async {
    final id = await PlanRepository.instance.create(name);
    await loadPlans();
    return id;
  }

  Future<void> scheduleWorkout(DateTime date, String planId, TimeOfDay time, {int repeatWeeks = 1}) async {
    final plan = plans.firstWhere((p) => p.id == planId);
    for (int i = 0; i < repeatWeeks; i++) {
      // DateTime constructor (not add) so a DST change can't shift the day.
      await _scheduleOne(DateTime(date.year, date.month, date.day + 7 * i), plan.id, plan.name, time);
    }
    await loadPlans();
  }

  /// Installs [program]: creates one plan per day and, when [weekdays] is
  /// non-empty, schedules the days in rotation on those weekdays for
  /// [weeks] weeks starting today. Returns how many sessions were scheduled.
  Future<int> installProgram(
    Program program, {
    List<int> weekdays = const [],
    int weeks = 4,
    TimeOfDay time = const TimeOfDay(hour: 18, minute: 0),
  }) async {
    final created = <(String, String)>[];
    for (final day in program.days) {
      final id = await PlanRepository.instance.createWithItems(day.name, [
        for (final e in day.exercises) (builtinExerciseId(e.name), e.sets, e.reps),
      ]);
      created.add((id, day.name));
    }

    var scheduled = 0;
    if (weekdays.isNotEmpty) {
      final today = DateTime.now();
      var next = 0;
      for (var offset = 0; offset < weeks * 7; offset++) {
        final date = DateTime(today.year, today.month, today.day + offset);
        if (!weekdays.contains(date.weekday)) continue;
        final (planId, planName) = created[next % created.length];
        await _scheduleOne(date, planId, planName, time);
        next++;
        scheduled++;
      }
    }
    await loadPlans();
    return scheduled;
  }

  /// Schedules one plan on one day, with a reminder at [time].
  Future<void> _scheduleOne(DateTime scheduledDate, String planId, String planName, TimeOfDay time) async {
    await ScheduleRepository.instance.set(
      scheduledDate,
      planId,
      reminderMinutes: time.hour * 60 + time.minute,
    );

    final scheduledDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      time.hour,
      time.minute,
    );
    final notificationId = reminderIdForDate(scheduledDate);

    // A failed or past-dated reminder shouldn't stop the other days from saving.
    try {
      await NotificationService.instance.cancelReminder(notificationId);
      await NotificationService.instance.scheduleWorkoutReminder(notificationId, planName, scheduledDateTime);
    } catch (e) {
      debugPrint('Failed to schedule reminder for ${dateKey(scheduledDate)}: $e');
    }
  }

  Future<void> updateTargets(String planId, String itemId, int sets, int? reps) async {
    await PlanRepository.instance.updateTargets(planId, itemId, sets, reps);
    await loadPlans();
  }

  Future<void> renamePlan(String planId, String name) async {
    await PlanRepository.instance.rename(planId, name);
    await loadPlans();
  }

  /// Moves the exercise at [oldIndex] so it ends up at [newIndex].
  Future<void> reorderPlan(String planId, int oldIndex, int newIndex) async {
    final plan = planById(planId);
    if (plan == null) return;
    final items = [...plan.items];
    items.insert(newIndex, items.removeAt(oldIndex));
    // Show the new order right away; the database write follows.
    plans = [
      for (final p in plans)
        p.id == planId ? WorkoutPlan(id: p.id, name: p.name, items: items) : p,
    ];
    notifyListeners();
    await PlanRepository.instance.reorder(planId, items.map((i) => i.id).toList());
    await loadPlans();
  }

  /// Deletes the plan, its schedules and their reminders.
  Future<void> deletePlan(String planId) async {
    final dates = await PlanRepository.instance.delete(planId);
    for (final key in dates) {
      try {
        await NotificationService.instance.cancelReminder(reminderIdForDate(parseDateKey(key)));
      } catch (e) {
        debugPrint('Failed to cancel reminder for $key: $e');
      }
    }
    await loadPlans();
  }

  /// Removes what's scheduled on [date] and cancels its reminder.
  Future<void> unschedule(DateTime date) async {
    await ScheduleRepository.instance.clear(date);
    try {
      await NotificationService.instance.cancelReminder(reminderIdForDate(date));
    } catch (e) {
      debugPrint('Failed to cancel reminder for ${dateKey(date)}: $e');
    }
    await loadPlans();
  }

  Future<void> addExerciseToPlan(String planId, String exerciseId) async {
    await PlanRepository.instance.addExercise(planId, exerciseId);
    await loadPlans();
  }

  Future<void> removeExerciseFromPlan(String planId, String exerciseId) async {
    await PlanRepository.instance.removeExercise(planId, exerciseId);
    await loadPlans();
  }
}
