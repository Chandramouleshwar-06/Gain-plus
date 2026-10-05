import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/exercise.dart';
import '../../services/database_service.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> exercises = [];

  Future<void> loadExercises() async {
    exercises = await DatabaseService.instance.getExercises();
    notifyListeners();
  }

  /// Returns false if an exercise with the same name already exists.
  Future<bool> addExercise(Exercise exercise) async {
    try {
      await DatabaseService.instance.insertExercise(exercise);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return false;
      rethrow;
    }
    await loadExercises();
    return true;
  }
}
