import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fresh install seeds unique exercises and default plans', () async {
    await deleteDatabase(join(await getDatabasesPath(), 'gym_tracker.db'));

    final exercises = await DatabaseService.instance.getExercises();
    final names = exercises.map((e) => e.name).toList();
    expect(names, isNotEmpty);
    expect(names.toSet().length, names.length);

    final plans = await DatabaseService.instance.getWorkoutPlans();
    expect(plans.map((p) => p.name), contains('Push (Chest/Shoulders/Triceps)'));
  });
}
