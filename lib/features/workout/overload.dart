import '../../models/workout.dart';
import '../../utils/units.dart';

/// What to aim for on an exercise today, based on last time.
class OverloadSuggestion {
  /// Suggested weight, in kg.
  final double weight;

  /// True when the suggestion is to add weight.
  final bool increase;
  final String message;

  OverloadSuggestion(this.weight, this.increase, this.message);
}

/// Lower-body lifts (legs, deadlifts) progress in bigger steps.
bool isLowerBody({required String exerciseName, required String muscleGroup}) =>
    muscleGroup.toLowerCase().contains('legs') || exerciseName.toLowerCase().contains('deadlift');

/// Double progression: once every set from last time reached the target
/// reps, add one weight step (2.5 / 5 kg or 5 / 10 lb); otherwise stay at
/// that weight and add reps. Without a target, the lowest rep count from
/// last time is the target. Returns null when there's nothing to go on.
OverloadSuggestion? suggestNext(
  List<SetEntry> previous, {
  int? targetReps,
  bool lowerBody = false,
  Units units = const Units.kg(),
}) {
  final working = previous.where((s) => !s.isWarmup).toList();
  final weighted = working.where((s) => s.weight > 0 && s.reps > 0).toList();
  if (weighted.isEmpty) return null;

  final topWeight = weighted.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  final topSets = weighted.where((s) => s.weight == topWeight).toList();
  final target = targetReps ?? topSets.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
  final allHit = topSets.every((s) => s.reps >= target) && topSets.length >= (working.length / 2).ceil();

  if (allHit && targetReps != null) {
    // Step up in the display unit so lb users get round numbers.
    final shown = (units.fromKg(topWeight) * 10).roundToDouble() / 10;
    final next = units.toKg(shown + units.increment(lowerBody: lowerBody));
    return OverloadSuggestion(
      next,
      true,
      'You hit every rep last time. Try ${units.weight(next)} today.',
    );
  }
  return OverloadSuggestion(
    topWeight,
    false,
    "Stay at ${units.weight(topWeight)} and beat last time's reps.",
  );
}
