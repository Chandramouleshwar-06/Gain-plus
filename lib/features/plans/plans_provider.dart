import 'package:flutter/material.dart';
import '../../models/workout_plan.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../utils/date_keys.dart';

class PlansProvider extends ChangeNotifier {
  List<WorkoutPlan> plans = [];
  Map<String, int> schedules = {}; // date_string -> planId

  Future<void> loadPlans() async {
    plans = await DatabaseService.instance.getWorkoutPlans();
    final dbSchedules = await DatabaseService.instance.getSchedules();
    schedules = {
      for (var s in dbSchedules) s['date'] as String: s['planId'] as int
    };
    notifyListeners();
  }

  Future<void> createPlan(String name) async {
    final plan = WorkoutPlan(
      name: name,
      exerciseIds: [],
    );
    await DatabaseService.instance.insertWorkoutPlan(plan);
    await loadPlans();
  }

  /// The plan scheduled for [date], if any.
  WorkoutPlan? planForDate(DateTime date) {
    final planId = schedules[scheduleDateKey(date)];
    if (planId == null) return null;
    return plans.where((p) => p.id == planId).firstOrNull;
  }

  Future<void> scheduleWorkout(DateTime date, int planId, TimeOfDay time, {int repeatWeeks = 1}) async {
    final plan = plans.firstWhere((p) => p.id == planId);

    for (int i = 0; i < repeatWeeks; i++) {
      // DateTime constructor (not add) so a DST change can't shift the day.
      final scheduledDate = DateTime(date.year, date.month, date.day + 7 * i);
      final dateStr = scheduleDateKey(scheduledDate);

      await DatabaseService.instance.deleteSchedule(dateStr);
      await DatabaseService.instance.insertSchedule(dateStr, planId);

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
        debugPrint('Failed to schedule reminder for $dateStr: $e');
      }
    }

    await loadPlans();
  }

  Future<void> addExerciseToPlan(int planId, int exerciseId) async {
    final planIndex = plans.indexWhere((p) => p.id == planId);
    if (planIndex != -1) {
      final plan = plans[planIndex];
      if (!plan.exerciseIds.contains(exerciseId)) {
        final updatedPlan = WorkoutPlan(
          id: plan.id,
          name: plan.name,
          exerciseIds: [...plan.exerciseIds, exerciseId],
        );
        await DatabaseService.instance.updateWorkoutPlan(updatedPlan);
        await loadPlans();
      }
    }
  }

  Future<void> removeExerciseFromPlan(int planId, int exerciseId) async {
    final planIndex = plans.indexWhere((p) => p.id == planId);
    if (planIndex != -1) {
      final plan = plans[planIndex];
      if (plan.exerciseIds.contains(exerciseId)) {
        final updatedPlan = WorkoutPlan(
          id: plan.id,
          name: plan.name,
          exerciseIds: plan.exerciseIds.where((id) => id != exerciseId).toList(),
        );
        await DatabaseService.instance.updateWorkoutPlan(updatedPlan);
        await loadPlans();
      }
    }
  }
}
