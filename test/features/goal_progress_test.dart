import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/features/profile/profile_provider.dart';
import 'package:gain_plus/models/profile.dart';

void main() {
  Goal goal(String type, double target, {double? start}) =>
      Goal(id: 'g', type: type, exerciseId: 'bench', targetValue: target, startValue: start);

  test('lift goal progresses from the starting PR to the target', () {
    final g = goal(Goal.typeLift, 100, start: 80);
    expect(ProfileProvider.goalProgress(g, 80), 0);
    expect(ProfileProvider.goalProgress(g, 90), 0.5);
    expect(ProfileProvider.goalProgress(g, 105), 1);
  });

  test('lift goal without a start counts from zero', () {
    expect(ProfileProvider.goalProgress(goal(Goal.typeLift, 100), 85), 0.85);
  });

  test('body weight goal works when losing weight', () {
    final g = goal(Goal.typeBodyWeight, 75, start: 80);
    expect(ProfileProvider.goalProgress(g, 80), 0);
    expect(ProfileProvider.goalProgress(g, 77.5), 0.5);
    expect(ProfileProvider.goalProgress(g, 81), 0, reason: 'going the wrong way clamps to 0');
    expect(ProfileProvider.goalProgress(g, 74), 1);
  });

  test('body weight goal works when gaining weight', () {
    final g = goal(Goal.typeBodyWeight, 70, start: 60);
    expect(ProfileProvider.goalProgress(g, 65), 0.5);
  });
}
