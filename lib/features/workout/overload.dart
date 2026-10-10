import '../../models/workout.dart';
import '../../utils/format.dart';

/// What to aim for on an exercise today, based on last time.
class OverloadSuggestion {
  final double weight;

  /// True when the suggestion is to add weight.
  final bool increase;
  final String message;

  OverloadSuggestion(this.weight, this.increase, this.message);
}

/// Weight to add for a lower-body lift vs. everything else.
double weightIncrement({required String exerciseName, required String muscleGroup}) {
  final name = exerciseName.toLowerCase();
  final heavy = muscleGroup.toLowerCase().contains('legs') || name.contains('deadlift');
  return heavy ? 5 : 2.5;
}

/// Double progression: once every set from last time reached the target
/// reps, add [increment]; otherwise stay at that weight and add reps.
/// Without a target, the lowest rep count from last time is the target.
/// Returns null when there is nothing to go on (no previous weighted sets).
OverloadSuggestion? suggestNext(List<SetEntry> previous, {int? targetReps, double increment = 2.5}) {
  final weighted = previous.where((s) => s.weight > 0 && s.reps > 0).toList();
  if (weighted.isEmpty) return null;

  final topWeight = weighted.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  final topSets = weighted.where((s) => s.weight == topWeight).toList();
  final target = targetReps ?? topSets.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
  final allHit = topSets.every((s) => s.reps >= target) && topSets.length >= (previous.length / 2).ceil();

  if (allHit && targetReps != null) {
    final next = topWeight + increment;
    return OverloadSuggestion(
      next,
      true,
      'You hit every rep last time. Try ${formatWeight(next)} kg today.',
    );
  }
  return OverloadSuggestion(
    topWeight,
    false,
    'Stay at ${formatWeight(topWeight)} kg and beat last time\'s reps.',
  );
}
