import 'package:flutter/material.dart';
import '../../data/plan_repository.dart';
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

  Future<void> createPlan(String name) async {
    await PlanRepository.instance.create(name);
    await loadPlans();
  }

  Future<void> scheduleWorkout(DateTime date, String planId, TimeOfDay time, {int repeatWeeks = 1}) async {
    final plan = plans.firstWhere((p) => p.id == planId);

    for (int i = 0; i < repeatWeeks; i++) {
      // DateTime constructor (not add) so a DST change can't shift the day.
      final scheduledDate = DateTime(date.year, date.month, date.day + 7 * i);

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

      // A failed or past-dated reminder shouldn't stop the remaining weeks from saving.
      try {
        await NotificationService.instance.cancelReminder(notificationId);
        await NotificationService.instance.scheduleWorkoutReminder(
          notificationId,
          plan.name,
          scheduledDateTime,
        );
      } catch (e) {
        debugPrint('Failed to schedule reminder for ${dateKey(scheduledDate)}: $e');
      }
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
