import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/exercise_guides.dart';
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/features/exercise/exercise_guide_screen.dart';

void main() {
  test('every built-in exercise has a complete guide', () {
    for (final e in seedExercises) {
      final guide = guideFor(e.name);
      expect(guide, isNotNull, reason: e.name);
      expect(guide!.setup, isNotEmpty, reason: e.name);
      expect(guide.steps.length, greaterThanOrEqualTo(2), reason: e.name);
      expect(guide.cues, isNotEmpty, reason: e.name);
      expect(guide.mistakes, isNotEmpty, reason: e.name);
    }
  });

  test('demo link searches YouTube for the exercise', () {
    final url = demoSearchUrl('Squat (Barbell)');
    expect(url.host, 'www.youtube.com');
    expect(url.queryParameters['search_query'], 'Squat (Barbell) proper form');
  });
}
