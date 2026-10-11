import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/services/home_widget_service.dart';

void main() {
  test('widget data covers the coming week and recent workout days', () {
    final now = DateTime(2026, 10, 11, 21, 30);
    final data = buildHomeWidgetData(
      now: now,
      workoutDates: [
        DateTime(2026, 10, 10, 7),
        DateTime(2026, 10, 10, 18), // twice in a day counts once
        DateTime(2026, 10, 9, 7),
        DateTime(2025, 1, 1), // too old to matter
      ],
      planFor: (day) => day.day == 12 ? ('Push Day', 6) : null,
      weeklyTarget: 4,
    );

    expect(data['workout_days'], '2026-10-09,2026-10-10');
    expect(data['weekly_target'], 4);
    expect(data['plan_2026-10-11'], '');
    expect(data['plan_2026-10-12'], 'Push Day|6');
    expect(data.keys.where((k) => k.startsWith('plan_')), hasLength(8), reason: 'today and the next 7 days');
    expect(data.containsKey('plan_2026-10-18'), isTrue);
  });
}
