import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/database_service.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> exercises = [];

  Future<void> loadExercises() async {
    exercises = await DatabaseService.instance.getExercises();
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    await DatabaseService.instance.insertExercise(exercise);
    await loadExercises();
  }
}
