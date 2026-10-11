import 'package:flutter/material.dart';
import '../../data/profile_repository.dart';
import '../../data/sync_columns.dart';
import '../../data/equipment.dart';
import '../../models/profile.dart';
import '../../utils/units.dart';

class ProfileProvider extends ChangeNotifier {
  bool loaded = false;
  Profile? profile;
  List<Goal> goals = [];

  /// Oldest first.
  List<BodyWeightEntry> bodyWeights = [];

  bool get needsOnboarding => loaded && profile?.onboardedAt == null;
  int get weeklyTarget => profile?.workoutsPerWeek ?? 3;

  /// Equipment available; everything when not set yet.
  Set<String> get availableEquipment => (profile?.equipment ?? Equipment.all).toSet();

  Future<void> setEquipment(List<String> equipment) async {
    await saveProfile((profile ?? const Profile()).copyWith(equipment: equipment));
  }

  /// The unit weights are shown and typed in.
  Units get units => Units.fromCode(profile?.units);

  Future<void> setUnits(Units value) async {
    await saveProfile((profile ?? const Profile()).copyWith(units: value.code));
  }
  double? get latestBodyWeight => bodyWeights.isEmpty ? null : bodyWeights.last.weightKg;

  /// First name for greetings, e.g. "CR".
  String get firstName {
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }

  Future<void> load() async {
    final repo = ProfileRepository.instance;
    profile = await repo.getProfile();
    goals = await repo.getGoals();
    bodyWeights = await repo.getBodyWeights();
    loaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(Profile updated) async {
    await ProfileRepository.instance.saveProfile(updated);
    profile = updated;
    notifyListeners();
  }

  /// Saves onboarding answers and an optional starting body weight.
  Future<void> completeOnboarding(Profile answers, {double? bodyWeightKg}) async {
    final repo = ProfileRepository.instance;
    await repo.saveProfile(answers);
    if (bodyWeightKg != null) await repo.addBodyWeight(DateTime.now(), bodyWeightKg);
    await load();
  }

  Future<void> addGoal({
    required String type,
    String? exerciseId,
    required double targetValue,
    double? startValue,
    DateTime? deadline,
  }) async {
    await ProfileRepository.instance.saveGoal(Goal(
      id: newId(),
      type: type,
      exerciseId: exerciseId,
      targetValue: targetValue,
      startValue: startValue,
      deadline: deadline,
    ));
    await load();
  }

  Future<void> deleteGoal(String id) async {
    await ProfileRepository.instance.deleteGoal(id);
    await load();
  }

  Future<void> logBodyWeight(double kg, {DateTime? date}) async {
    await ProfileRepository.instance.addBodyWeight(date ?? DateTime.now(), kg);
    await load();
  }

  Future<void> deleteBodyWeight(String id) async {
    await ProfileRepository.instance.deleteBodyWeight(id);
    await load();
  }

  /// Marks goals reached as achieved. [prKgByExerciseId] is the heaviest
  /// set per exercise. Returns the goals that were newly achieved.
  Future<List<Goal>> markAchievedGoals(Map<String, double> prKgByExerciseId) async {
    final newlyAchieved = <Goal>[];
    for (final goal in goals) {
      if (goal.achievedAt != null) continue;
      final current = currentValue(goal, prKgByExerciseId);
      if (current == null || goalProgress(goal, current) < 1) continue;
      final achieved = Goal(
        id: goal.id,
        type: goal.type,
        exerciseId: goal.exerciseId,
        targetValue: goal.targetValue,
        startValue: goal.startValue,
        deadline: goal.deadline,
        achievedAt: DateTime.now(),
      );
      await ProfileRepository.instance.saveGoal(achieved);
      newlyAchieved.add(achieved);
    }
    if (newlyAchieved.isNotEmpty) await load();
    return newlyAchieved;
  }

  /// The value a goal is measured against right now, or null if unknown.
  double? currentValue(Goal goal, Map<String, double> prKgByExerciseId) {
    return switch (goal.type) {
      Goal.typeLift => prKgByExerciseId[goal.exerciseId],
      Goal.typeBodyWeight => latestBodyWeight,
      _ => null,
    };
  }

  /// 0..1 progress from the starting value towards the target. Works for
  /// goals that go down (losing weight) as well as up.
  static double goalProgress(Goal goal, double current) {
    final start = goal.startValue ?? (goal.type == Goal.typeLift ? 0 : current);
    final total = goal.targetValue - start;
    if (total == 0) return current == goal.targetValue ? 1 : 0;
    return ((current - start) / total).clamp(0.0, 1.0);
  }
}
