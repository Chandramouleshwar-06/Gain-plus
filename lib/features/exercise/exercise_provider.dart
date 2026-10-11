import 'package:flutter/material.dart';
import '../../data/equipment.dart';
import '../../data/exercise_repository.dart';
import '../../data/seed_data.dart';
import '../../models/exercise.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> exercises = [];

  Exercise? byId(String id) => exercises.where((e) => e.id == id).firstOrNull;

  /// Exercises you can do with [available] equipment that work the same
  /// main muscle as [exercise], best match first: built-ins in their
  /// original order, then custom ones.
  List<Exercise> alternativesFor(Exercise exercise, Set<String> available) {
    final candidates = exercises
        .where((e) => e.id != exercise.id && e.primaryMuscle == exercise.primaryMuscle)
        .where((e) => hasEquipmentFor(e.equipment, available))
        .toList();
    final seedOrder = {for (var i = 0; i < seedExercises.length; i++) seedExercises[i].name: i};
    candidates.sort((a, b) => (seedOrder[a.name] ?? 999).compareTo(seedOrder[b.name] ?? 999));
    return candidates;
  }

  Future<void> loadExercises() async {
    exercises = await ExerciseRepository.instance.getAll();
    notifyListeners();
  }

  /// Muscle groups for filtering, e.g. "Back/Biceps" counts as Back and Biceps.
  List<String> get muscleGroups {
    final groups = <String>{};
    for (final e in exercises) {
      groups.addAll(e.muscleGroup.split('/').map((g) => g.trim()).where((g) => g.isNotEmpty));
    }
    return groups.toList()..sort();
  }

  Future<void> deleteExercise(String id) async {
    await ExerciseRepository.instance.deleteCustom(id);
    await loadExercises();
  }

  /// Returns false if an exercise with the same name already exists.
  Future<bool> addExercise({
    required String name,
    required String muscleGroup,
    String notes = '',
    List<String> equipment = const [],
  }) async {
    final added = await ExerciseRepository.instance.addCustom(
      name: name,
      muscleGroup: muscleGroup,
      notes: notes,
      equipment: equipment,
    );
    if (added == null) return false;
    await loadExercises();
    return true;
  }
}
