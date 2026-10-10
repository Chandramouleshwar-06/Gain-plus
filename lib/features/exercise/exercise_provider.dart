import 'package:flutter/material.dart';
import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> exercises = [];

  Exercise? byId(String id) => exercises.where((e) => e.id == id).firstOrNull;

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
  }) async {
    final added = await ExerciseRepository.instance.addCustom(
      name: name,
      muscleGroup: muscleGroup,
      notes: notes,
    );
    if (added == null) return false;
    await loadExercises();
    return true;
  }
}
