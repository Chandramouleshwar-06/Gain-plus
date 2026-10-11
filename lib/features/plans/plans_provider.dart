import 'package:flutter/material.dart';
import '../../data/plan_repository.dart';
import '../../data/schedule_repository.dart';
import '../../models/workout_plan.dart';
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

  WorkoutPlan? planById(String id) =>
      plans.where((p) => p.id == id).firstOrNull;

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

  Future<void> scheduleWorkout(
    DateTime date,
    String planId,
    TimeOfDay time, {
    int repeatWeeks = 1,
  }) async {
    final plan = plans.firstWhere((p) => p.id == planId);
    for (int i = 0; i < repeatWeeks; i++) {
      // DateTime constructor (not add) so a DST change can't shift the day.
      await _scheduleOne(
        DateTime(date.year, date.month, date.day + 7 * i),
        plan.id,
        time,
      );
    }
    await loadPlans();
  }

  /// Schedules one plan on one day. Its reminder at [time] is set up by the
  /// reminder engine, which re-plans whenever schedules change.
  Future<void> _scheduleOne(
    DateTime scheduledDate,
    String planId,
    TimeOfDay time,
  ) async {
    await ScheduleRepository.instance.set(
      scheduledDate,
      planId,
      reminderMinutes: time.hour * 60 + time.minute,
    );
  }

  Future<void> updateTargets(
    String planId,
    String itemId,
    int sets,
    int? reps,
  ) async {
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
    await PlanRepository.instance.reorder(
      planId,
      items.map((i) => i.id).toList(),
    );
    await loadPlans();
  }

  /// Deletes the plan and its schedules.
  Future<void> deletePlan(String planId) async {
    await PlanRepository.instance.delete(planId);
    await loadPlans();
  }

  /// Removes what's scheduled on [date].
  Future<void> unschedule(DateTime date) async {
    await ScheduleRepository.instance.clear(date);
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
