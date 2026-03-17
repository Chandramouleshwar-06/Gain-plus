import 'package:flutter/material.dart';
import '../../models/workout_plan.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';

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

  Future<void> scheduleWorkout(DateTime date, int planId, TimeOfDay time, {int repeatWeeks = 1}) async {
    final plan = plans.firstWhere((p) => p.id == planId);
    
    for (int i = 0; i < repeatWeeks; i++) {
      final scheduledDate = date.add(Duration(days: 7 * i));
      final dateStr = "${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}";
      
      await DatabaseService.instance.deleteSchedule(dateStr);
      await DatabaseService.instance.insertSchedule(dateStr, planId);
      
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        time.hour,
        time.minute,
      );

      // Unique ID for notification
      final notificationId = scheduledDate.year * 10000 + scheduledDate.month * 100 + scheduledDate.day;
      
      await NotificationService.instance.scheduleWorkoutReminder(
        notificationId,
        plan.name,
        scheduledDateTime,
      );
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
