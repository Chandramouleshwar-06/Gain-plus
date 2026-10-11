import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/equipment.dart';
import 'package:gain_plus/data/plan_repository.dart';
import 'package:gain_plus/data/profile_repository.dart';
import 'package:gain_plus/data/programs.dart' as ready show programs;
import 'package:gain_plus/data/seed_data.dart';
import 'package:gain_plus/features/exercise/exercise_provider.dart';
import 'package:gain_plus/features/plans/programs_provider.dart';
import 'package:gain_plus/models/profile.dart';

import '../helpers/test_db.dart';

void main() {
  setUpAll(useFfiDatabase);
  setUp(resetDatabase);

  test('every equipment entry names a real built-in exercise', () {
    final names = seedExercises.map((e) => e.name).toSet();
    for (final name in builtinEquipment.keys) {
      expect(names, contains(name));
    }
  });

  test('built-ins get equipment from code; custom exercises store their own', () async {
    final provider = ExerciseProvider();
    await provider.loadExercises();
    final bench = provider.byId(builtinExerciseId('Bench Press (Barbell)'))!;
    expect(bench.equipment, [Equipment.barbell, Equipment.bench]);
    expect(provider.byId(builtinExerciseId('Push Ups'))!.equipment, isEmpty);

    await provider.addExercise(name: 'Band Pull Apart', muscleGroup: 'Shoulders', equipment: [Equipment.cable]);
    final custom = provider.exercises.firstWhere((e) => e.name == 'Band Pull Apart');
    expect(custom.equipment, [Equipment.cable]);
  });

  test('alternatives work the same muscle and only use available equipment', () async {
    final provider = ExerciseProvider();
    await provider.loadExercises();
    final bench = provider.byId(builtinExerciseId('Bench Press (Barbell)'))!;

    final withDumbbells = provider.alternativesFor(bench, {Equipment.dumbbell, Equipment.bench});
    expect(withDumbbells.map((e) => e.name), contains('Dumbbell Flys'));
    expect(withDumbbells.every((e) => e.primaryMuscle == 'Chest'), isTrue);
    expect(withDumbbells.map((e) => e.name), isNot(contains('Chest Press (Machine)')));

    final bodyweight = provider.alternativesFor(bench, {});
    expect(bodyweight.first.name, 'Push Ups', reason: 'built-in order, bodyweight only');
  });

  test('profile equipment round-trips; unset means a full gym', () async {
    final repo = ProfileRepository.instance;
    await repo.saveProfile(const Profile(name: 'CR'));
    expect((await repo.getProfile())!.equipment, isNull);
    await repo.saveProfile(const Profile(name: 'CR', equipment: [Equipment.dumbbell]));
    expect((await repo.getProfile())!.equipment, [Equipment.dumbbell]);
  });

  test('copying a ready-made program applies equipment swaps', () async {
    final exercises = ExerciseProvider();
    await exercises.loadExercises();
    final programs = ProgramsProvider();
    final legPress = builtinExerciseId('Leg Press');
    final lunges = builtinExerciseId('Lunges (Dumbbell)');

    final ppl = ready.programs.firstWhere((p) => p.id == 'push-pull-legs');
    final id = await programs.copyBuiltin(ppl, swaps: {'Leg Press': lunges});
    final planIds = programs.byId(id)!.planIds;
    final allPlans = await PlanRepository.instance.getAll();
    final legs = allPlans.firstWhere((p) => p.id == planIds[2]);
    expect(legs.exerciseIds, contains(lunges));
    expect(legs.exerciseIds, isNot(contains(legPress)));
  });
}
