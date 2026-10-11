import '../../data/muscles.dart';

/// One working set of an exercise, for muscle analysis.
class MuscleSet {
  final DateTime date;
  final MuscleMap muscles;

  MuscleSet(this.date, this.muscles);
}

/// Load at which a muscle counts as fully fatigued (about 6 hard sets
/// just done).
const fullFatigueLoad = 6.0;

/// Remaining fatigue per muscle at [now]: each set adds 1 to its primary
/// muscles and 0.5 to secondary ones, fading linearly to zero over the
/// muscle's recovery time.
Map<Muscle, double> muscleLoad(Iterable<MuscleSet> sets, DateTime now) {
  final load = <Muscle, double>{};
  void add(Muscle m, double credit, double hoursAgo) {
    final remaining = 1 - hoursAgo / m.recoveryHours;
    if (remaining <= 0) return;
    load[m] = (load[m] ?? 0) + credit * remaining;
  }

  for (final s in sets) {
    final hoursAgo = now.difference(s.date).inMinutes / 60;
    if (hoursAgo < 0) continue;
    for (final m in s.muscles.$1) {
      add(m, 1, hoursAgo);
    }
    for (final m in s.muscles.$2) {
      add(m, 0.5, hoursAgo);
    }
  }
  return load;
}

/// 0..1 where 1 is fully recovered.
double recoveryFor(Muscle muscle, Map<Muscle, double> load) =>
    (1 - (load[muscle] ?? 0) / fullFatigueLoad).clamp(0.0, 1.0);

enum RecoveryStatus { fresh, recovering, tired }

/// Whole hours until each muscle that isn't ready yet becomes ready
/// (checked hour by hour, up to the longest recovery time).
Map<Muscle, int> hoursUntilReady(Iterable<MuscleSet> sets, DateTime now) {
  final pending = {
    for (final m in Muscle.values)
      if (statusFor(recoveryFor(m, muscleLoad(sets, now))) != RecoveryStatus.fresh) m,
  };
  final result = <Muscle, int>{};
  final maxHours = Muscle.values.map((m) => m.recoveryHours).reduce((a, b) => a > b ? a : b);
  for (var h = 1; h <= maxHours && pending.isNotEmpty; h++) {
    final load = muscleLoad(sets, now.add(Duration(hours: h)));
    for (final m in pending.toList()) {
      if (statusFor(recoveryFor(m, load)) == RecoveryStatus.fresh) {
        result[m] = h;
        pending.remove(m);
      }
    }
  }
  return result;
}

RecoveryStatus statusFor(double recovery) => recovery >= 0.85
    ? RecoveryStatus.fresh
    : recovery >= 0.45
        ? RecoveryStatus.recovering
        : RecoveryStatus.tired;

/// Hard sets per muscle group over the 7 days before [now]: a full set for
/// each primary muscle's group, half for secondary groups not already
/// credited by that set.
Map<String, double> weeklyGroupSets(Iterable<MuscleSet> sets, DateTime now) {
  final from = now.subtract(const Duration(days: 7));
  final totals = {for (final g in Muscle.groups) g: 0.0};
  for (final s in sets) {
    if (s.date.isBefore(from) || s.date.isAfter(now)) continue;
    final primaryGroups = s.muscles.$1.map((m) => m.group).toSet();
    for (final g in primaryGroups) {
      totals[g] = totals[g]! + 1;
    }
    for (final g in s.muscles.$2.map((m) => m.group).toSet().difference(primaryGroups)) {
      totals[g] = totals[g]! + 0.5;
    }
  }
  return totals;
}

/// Commonly recommended weekly hard sets per muscle group for growth.
const recommendedWeeklySets = (10.0, 20.0);
