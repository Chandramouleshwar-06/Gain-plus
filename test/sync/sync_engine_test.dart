import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/data/plan_repository.dart';
import 'package:gain_plus/data/schedule_repository.dart';
import 'package:gain_plus/data/sync_columns.dart';
import 'package:gain_plus/data/workout_repository.dart';
import 'package:gain_plus/models/workout.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:gain_plus/sync/remote_store.dart';
import 'package:gain_plus/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_db.dart';

/// Simulates several phones on one account: each "device" has its own
/// database file and preferences, swapped in and out of place.
class Devices {
  final Map<String, Map<String, Object>> _prefs = {};
  String? current;

  Future<void> use(String name) async {
    final path = await testDbPath();
    if (current != null) {
      await DatabaseService.instance.close();
      await File(path).copy('$path.$current');
      final prefs = await SharedPreferences.getInstance();
      _prefs[current!] = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
    }
    await DatabaseService.instance.close();
    final saved = File('$path.$name');
    if (await saved.exists()) {
      await saved.copy(path);
    } else {
      await deleteTestDatabase();
    }
    SharedPreferences.setMockInitialValues(_prefs[name] ?? {});
    current = name;
  }
}

Future<void> deleteTestDatabase() async {
  final file = File(await testDbPath());
  if (await file.exists()) await file.delete();
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  const uid = 'user-1';
  late MemoryRemoteStore cloud;
  late SyncEngine engine;
  late Devices devices;

  setUpAll(useFfiDatabase);
  setUp(() async {
    await resetDatabase();
    final path = await testDbPath();
    for (final name in ['phone', 'tablet']) {
      final f = File('$path.$name');
      if (await f.exists()) await f.delete();
    }
    cloud = MemoryRemoteStore();
    engine = SyncEngine(cloud);
    devices = Devices();
    SharedPreferences.setMockInitialValues({});
  });

  Future<String> logWorkout(String name) async {
    final id = newId();
    await WorkoutRepository.instance.save(Workout(
      id: id,
      name: name,
      startedAt: DateTime(2026, 10, 10, 9),
      durationSeconds: 1800,
      totalVolume: 1000,
      exercises: [
        ExerciseEntry(id: newId(), exerciseId: 'builtin-ex-bench-press-barbell', exerciseName: 'Bench', position: 0, sets: [
          SetEntry(id: newId(), position: 0, weight: 100, reps: 10),
        ]),
      ],
    ));
    return id;
  }

  test('changes upload once; built-in seed rows are never uploaded', () async {
    await devices.use('phone');
    await PlanRepository.instance.create('My Plan');
    await logWorkout('Morning');

    final first = await engine.sync(uid);
    expect(first.pushed, 4, reason: 'plan, workout, entry, set');
    expect(cloud.rows(uid, 'exercises'), isEmpty, reason: 'seeds stay local');
    expect(cloud.rows(uid, 'plans').map((r) => r['name']), ['My Plan']);
    expect(cloud.rows(uid, 'plans').single.containsKey('dirty'), isFalse);

    expect(await SyncEngine.pendingChanges(), 0);
    expect((await engine.sync(uid)).pushed, 0, reason: 'nothing changed');
  });

  test('a second device gets everything, and edits flow both ways', () async {
    await devices.use('phone');
    final planId = await PlanRepository.instance.create('Push');
    final workoutId = await logWorkout('Morning');
    await engine.sync(uid);

    await devices.use('tablet');
    final pulled = await engine.sync(uid);
    expect(pulled.pulled, greaterThan(0));
    expect((await PlanRepository.instance.getAll()).map((p) => p.name), contains('Push'));
    final w = await WorkoutRepository.instance.getWithDetails(workoutId);
    expect(w!.exercises.single.sets.single.weight, 100);
    expect(await SyncEngine.pendingChanges(), 0, reason: 'pulled rows are not dirty');

    // Tablet renames the plan; phone sees it.
    await PlanRepository.instance.rename(planId, 'Push A');
    await engine.sync(uid);
    await devices.use('phone');
    await engine.sync(uid);
    expect((await PlanRepository.instance.getAll()).firstWhere((p) => p.id == planId).name, 'Push A');
  });

  test('when both devices edit the same row, the newest edit wins everywhere', () async {
    await devices.use('phone');
    final planId = await PlanRepository.instance.create('Legs');
    await engine.sync(uid);
    await devices.use('tablet');
    await engine.sync(uid);

    // Offline edits on both; the tablet's is later.
    await devices.use('phone');
    await PlanRepository.instance.rename(planId, 'Legs (phone)');
    await tick();
    await devices.use('tablet');
    await PlanRepository.instance.rename(planId, 'Legs (tablet)');

    await engine.sync(uid); // tablet uploads its newer edit
    await devices.use('phone');
    await engine.sync(uid); // phone's older edit loses, nothing stale is uploaded
    expect((await PlanRepository.instance.getAll()).firstWhere((p) => p.id == planId).name, 'Legs (tablet)');
    expect(cloud.rows(uid, 'plans').single['name'], 'Legs (tablet)');
  });

  test('deletions sync', () async {
    await devices.use('phone');
    final workoutId = await logWorkout('To delete');
    await engine.sync(uid);
    await devices.use('tablet');
    await engine.sync(uid);
    await WorkoutRepository.instance.delete(workoutId);
    await engine.sync(uid);

    await devices.use('phone');
    await engine.sync(uid);
    expect(await WorkoutRepository.instance.getWithDetails(workoutId), isNull);
    expect(await WorkoutRepository.instance.getRecent(), isEmpty);
  });

  test('two devices scheduling the same day: the newer schedule wins, no duplicates', () async {
    final day = DateTime(2026, 11, 2);
    await devices.use('phone');
    await ScheduleRepository.instance.set(day, 'builtin-plan-push');
    await engine.sync(uid);

    await devices.use('tablet');
    await tick();
    await ScheduleRepository.instance.set(day, 'builtin-plan-pull'); // offline, later
    await engine.sync(uid); // pulls phone's Push for the same day, keeps its newer Pull

    final tabletDay = await ScheduleRepository.instance.getAll();
    expect(tabletDay['2026-11-02']!.planId, 'builtin-plan-pull');

    await devices.use('phone');
    await engine.sync(uid);
    final phoneDay = await ScheduleRepository.instance.getAll();
    expect(phoneDay.length, 1);
    expect(phoneDay['2026-11-02']!.planId, 'builtin-plan-pull');
  });

  test('custom exercises with the same name on two devices are de-duplicated', () async {
    await devices.use('phone');
    final db1 = await DatabaseService.instance.database;
    await db1.insert('exercises', touched({'id': 'a', 'name': 'Cable Fly', 'muscleGroup': 'Chest', 'notes': '', 'isCustom': 1}));
    await engine.sync(uid);

    await devices.use('tablet');
    await tick();
    final db2 = await DatabaseService.instance.database;
    await db2.insert('exercises', touched({'id': 'b', 'name': 'Cable Fly', 'muscleGroup': 'Chest', 'notes': '', 'isCustom': 1}));
    await engine.sync(uid);
    await devices.use('phone');
    await engine.sync(uid);

    final db = await DatabaseService.instance.database;
    final live = await db.query('exercises', where: "name = 'Cable Fly' AND deletedAt IS NULL");
    expect(live.map((r) => r['id']), ['b'], reason: 'newer one kept');
  });

  test('plans that used a retired duplicate exercise move to the one kept', () async {
    await devices.use('phone');
    final db1 = await DatabaseService.instance.database;
    await db1.insert('exercises', touched({'id': 'a', 'name': 'Cable Fly', 'muscleGroup': 'Chest', 'notes': '', 'isCustom': 1}));
    await db1.insert('plans', touched({'id': 'p', 'name': 'Chest day'}));
    await db1.insert('plan_exercises',
        touched({'id': 'pe', 'planId': 'p', 'exerciseId': 'a', 'position': 0, 'targetSets': 3, 'targetReps': 10}));
    await engine.sync(uid);

    await devices.use('tablet');
    await tick();
    final db2 = await DatabaseService.instance.database;
    await db2.insert('exercises', touched({'id': 'b', 'name': 'Cable Fly', 'muscleGroup': 'Chest', 'notes': '', 'isCustom': 1}));
    await engine.sync(uid);
    await tick();
    await engine.sync(uid); // uploads the repointed plan row
    await devices.use('phone');
    await engine.sync(uid);

    for (final device in ['phone', 'tablet']) {
      await devices.use(device);
      await engine.sync(uid);
      final db = await DatabaseService.instance.database;
      final row = (await db.query('plan_exercises', where: "id = 'pe'")).single;
      expect(row['exerciseId'], 'b', reason: '$device: plan keeps its exercise');
    }
  });
}
