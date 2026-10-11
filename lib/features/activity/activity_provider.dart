import 'package:flutter/material.dart';
import '../../data/activity_repository.dart';
import '../../data/activity_types.dart';
import '../../models/activity.dart';
import '../profile/profile_provider.dart';

/// Recent activities and calories burned per day.
class ActivityProvider extends ChangeNotifier {
  /// The last 30 days, newest first.
  List<Activity> recent = [];
  double burnedToday = 0;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<Activity> get today {
    final start = _today();
    return recent.where((a) => !a.startedAt.isBefore(start)).toList();
  }

  Future<void> load() async {
    final repo = ActivityRepository.instance;
    recent = await repo.getActivities(since: _today().subtract(const Duration(days: 30)));
    burnedToday = await repo.burnedOn(_today());
    notifyListeners();
  }

  Future<double> burnedOn(DateTime day) => ActivityRepository.instance.burnedOn(day);

  Future<void> save(Activity activity) async {
    await ActivityRepository.instance.save(activity);
    await load();
  }

  Future<void> delete(String id) async {
    await ActivityRepository.instance.delete(id);
    await load();
  }
}

/// Body metrics from the profile and latest weigh-in, for calorie estimates.
BodyMetrics bodyMetricsOf(ProfileProvider profile, {int? currentYear}) {
  final p = profile.profile;
  final year = currentYear ?? DateTime.now().year;
  return BodyMetrics(
    weightKg: profile.latestBodyWeight,
    heightCm: p?.heightCm,
    age: p?.birthYear == null ? null : year - p!.birthYear!,
    sex: p?.sex,
  );
}
