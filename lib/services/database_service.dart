import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gym_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        duration INTEGER NOT NULL,
        totalVolume REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        exerciseName TEXT NOT NULL,
        FOREIGN KEY (workoutId) REFERENCES workouts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE set_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseEntryId INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        completed INTEGER NOT NULL,
        FOREIGN KEY (exerciseEntryId) REFERENCES exercise_entries (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        exerciseIds TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        notes TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        planId INTEGER NOT NULL,
        FOREIGN KEY (planId) REFERENCES workout_plans (id)
      )
    ''');

    await _insertDefaultExercises(db);
    await _insertDefaultPlans(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE schedules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          planId INTEGER NOT NULL,
          FOREIGN KEY (planId) REFERENCES workout_plans (id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await _insertDefaultExercises(db);
    }
    if (oldVersion < 4) {
      await _insertDefaultPlans(db);
    }
  }

  Future _insertDefaultExercises(Database db) async {
    final exercises = [
      // Chest
      {'name': 'Bench Press (Barbell)', 'muscleGroup': 'Chest', 'notes': 'Middle chest'},
      {'name': 'Incline Bench Press (Barbell)', 'muscleGroup': 'Chest', 'notes': 'Upper chest'},
      {'name': 'Dumbbell Flys', 'muscleGroup': 'Chest', 'notes': 'Chest isolation'},
      {'name': 'Push Ups', 'muscleGroup': 'Chest', 'notes': 'Bodyweight calisthenics'},
      {'name': 'Chest Press (Machine)', 'muscleGroup': 'Chest', 'notes': 'Controlled movement'},
      {'name': 'Diamond Push Ups', 'muscleGroup': 'Chest/Triceps', 'notes': 'Inner chest focused calisthenics'},
      {'name': 'Dips (Chest Focus)', 'muscleGroup': 'Chest/Triceps', 'notes': 'Leaning forward calisthenics'},
      
      // Legs
      {'name': 'Squat (Barbell)', 'muscleGroup': 'Legs', 'notes': 'Quads and Glutes'},
      {'name': 'Leg Press', 'muscleGroup': 'Legs', 'notes': 'Machine quads'},
      {'name': 'Leg Extension', 'muscleGroup': 'Legs', 'notes': 'Quad isolation'},
      {'name': 'Leg Curl', 'muscleGroup': 'Legs', 'notes': 'Hamstrings'},
      {'name': 'Lunges (Dumbbell)', 'muscleGroup': 'Legs', 'notes': 'Unilateral legs'},
      {'name': 'Calf Raise', 'muscleGroup': 'Legs', 'notes': 'Calves'},
      {'name': 'Pistol Squats', 'muscleGroup': 'Legs', 'notes': 'Advanced unilateral calisthenics'},
      {'name': 'Bulgarian Split Squats', 'muscleGroup': 'Legs', 'notes': 'Quad focus'},
      
      // Back
      {'name': 'Deadlift (Barbell)', 'muscleGroup': 'Back', 'notes': 'Posterior chain'},
      {'name': 'Pull Up', 'muscleGroup': 'Back', 'notes': 'Width calisthenics'},
      {'name': 'Chin Up', 'muscleGroup': 'Back/Biceps', 'notes': 'Bicep focus calisthenics'},
      {'name': 'Lat Pulldown', 'muscleGroup': 'Back', 'notes': 'Width - Machine'},
      {'name': 'Barbell Row', 'muscleGroup': 'Back', 'notes': 'Thickness'},
      {'name': 'Seated Cable Row', 'muscleGroup': 'Back', 'notes': 'Middle back'},
      {'name': 'Dumbbell Row', 'muscleGroup': 'Back', 'notes': 'Single arm back'},
      {'name': 'Australian Pull Ups', 'muscleGroup': 'Back', 'notes': 'Inverted rows calisthenics'},
      {'name': 'Muscle Up', 'muscleGroup': 'Back/Arms', 'notes': 'Explosive calisthenics'},
      
      // Shoulders
      {'name': 'Overhead Press (Barbell)', 'muscleGroup': 'Shoulders', 'notes': 'Front/Side delts'},
      {'name': 'Lateral Raise (Dumbbell)', 'muscleGroup': 'Shoulders', 'notes': 'Side delt isolation'},
      {'name': 'Front Raise (Dumbbell)', 'muscleGroup': 'Shoulders', 'notes': 'Front delt isolation'},
      {'name': 'Shoulder Press (Dumbbell)', 'muscleGroup': 'Shoulders', 'notes': 'Stability shoulders'},
      {'name': 'Rear Delt Fly (Machine)', 'muscleGroup': 'Shoulders', 'notes': 'Rear delt isolation'},
      {'name': 'Handstand Push Ups', 'muscleGroup': 'Shoulders', 'notes': 'Advanced shoulder calisthenics'},
      {'name': 'Pike Push Ups', 'muscleGroup': 'Shoulders', 'notes': 'Shoulder focus calisthenics'},
      
      // Arms
      {'name': 'Bicep Curl (Dumbbell)', 'muscleGroup': 'Biceps', 'notes': 'Biceps'},
      {'name': 'Hammer Curl (Dumbbell)', 'muscleGroup': 'Biceps', 'notes': 'Brachialis/Forearms'},
      {'name': 'Tricep Pushdown (Cable)', 'muscleGroup': 'Triceps', 'notes': 'Tricep isolation'},
      {'name': 'Tricep Dip', 'muscleGroup': 'Triceps', 'notes': 'Parallel bar calisthenics'},
      {'name': 'Preacher Curl', 'muscleGroup': 'Biceps', 'notes': 'Bicep isolation'},
      {'name': 'Skull Crushers', 'muscleGroup': 'Triceps', 'notes': 'Tricep extension'},
      
      // Core & Full Body
      {'name': 'Plank', 'muscleGroup': 'Core', 'notes': 'Stability'},
      {'name': 'Crunches', 'muscleGroup': 'Core', 'notes': 'Abs'},
      {'name': 'Leg Raise', 'muscleGroup': 'Core', 'notes': 'Lower abs calisthenics'},
      {'name': 'L-Sit', 'muscleGroup': 'Core/Arms', 'notes': 'Isometric calisthenics'},
      {'name': 'Burpees', 'muscleGroup': 'Full Body', 'notes': 'Conditioning calisthenics'},
      {'name': 'Hollow Body Hold', 'muscleGroup': 'Core', 'notes': 'Core foundation'},
    ];

    for (var exercise in exercises) {
      await db.insert('exercises', exercise, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _insertDefaultPlans(Database db) async {
    // Get all exercises to map names to IDs
    final List<Map<String, dynamic>> exercises = await db.query('exercises');
    int getId(String name) => exercises.firstWhere((e) => e['name'] == name)['id'];

    try {
      final defaultPlans = [
        {
          'name': 'Push (Chest/Shoulders/Triceps)',
          'exerciseIds': [
            getId('Bench Press (Barbell)'),
            getId('Overhead Press (Barbell)'),
            getId('Incline Bench Press (Barbell)'),
            getId('Lateral Raise (Dumbbell)'),
            getId('Tricep Pushdown (Cable)'),
            getId('Dips (Chest Focus)'),
          ].join(',')
        },
        {
          'name': 'Pull (Back/Biceps)',
          'exerciseIds': [
            getId('Deadlift (Barbell)'),
            getId('Pull Up'),
            getId('Barbell Row'),
            getId('Seated Cable Row'),
            getId('Bicep Curl (Dumbbell)'),
            getId('Hammer Curl (Dumbbell)'),
          ].join(',')
        },
        {
          'name': 'Legs (Quads/Hams/Calves)',
          'exerciseIds': [
            getId('Squat (Barbell)'),
            getId('Leg Press'),
            getId('Leg Extension'),
            getId('Leg Curl'),
            getId('Bulgarian Split Squats'),
            getId('Calf Raise'),
          ].join(',')
        },
        {
          'name': 'Calisthenics Basic',
          'exerciseIds': [
            getId('Push Ups'),
            getId('Pull Up'),
            getId('Dips (Chest Focus)'),
            getId('Australian Pull Ups'),
            getId('Pike Push Ups'),
            getId('Leg Raise'),
          ].join(',')
        },
        {
          'name': 'Full Body (Basic)',
          'exerciseIds': [
            getId('Squat (Barbell)'),
            getId('Bench Press (Barbell)'),
            getId('Barbell Row'),
            getId('Overhead Press (Barbell)'),
            getId('Plank'),
          ].join(',')
        },
      ];

      for (var plan in defaultPlans) {
        await db.insert('workout_plans', plan, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      // Error inserting default plans
      rethrow;
    }
  }

  // Schedule methods
  Future<int> insertSchedule(String date, int planId) async {
    final db = await database;
    return await db.insert('schedules', {'date': date, 'planId': planId});
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await database;
    return await db.query('schedules');
  }

  Future<void> deleteSchedule(String date) async {
    final db = await database;
    await db.delete('schedules', where: 'date = ?', whereArgs: [date]);
  }

  // Original methods
  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return await db.insert('workouts', workout.toMap());
  }

  Future<int> insertExerciseEntry(ExerciseEntry entry) async {
    final db = await database;
    return await db.insert('exercise_entries', entry.toMap());
  }

  Future<int> insertSetEntry(SetEntry set) async {
    final db = await database;
    return await db.insert('set_entries', set.toMap());
  }

  Future<List<Workout>> getWorkouts() async {
    final db = await database;
    final result = await db.query('workouts', orderBy: 'date DESC');
    return result.map((map) => Workout.fromMap(map)).toList();
  }

  Future<List<ExerciseEntry>> getExerciseEntries(int workoutId) async {
    final db = await database;
    final result = await db.query(
      'exercise_entries',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
    
    List<ExerciseEntry> entries = [];
    for (var map in result) {
      final entry = ExerciseEntry.fromMap(map);
      final sets = await getSetEntries(entry.id!);
      entries.add(ExerciseEntry(
        id: entry.id,
        workoutId: entry.workoutId,
        exerciseId: entry.exerciseId,
        exerciseName: entry.exerciseName,
        sets: sets,
      ));
    }
    return entries;
  }

  Future<List<SetEntry>> getSetEntries(int exerciseEntryId) async {
    final db = await database;
    final result = await db.query(
      'set_entries',
      where: 'exerciseEntryId = ?',
      whereArgs: [exerciseEntryId],
    );
    return result.map((map) => SetEntry.fromMap(map)).toList();
  }

  Future<int> insertWorkoutPlan(WorkoutPlan plan) async {
    final db = await database;
    return await db.insert('workout_plans', plan.toMap());
  }

  Future<int> updateWorkoutPlan(WorkoutPlan plan) async {
    final db = await database;
    return await db.update(
      'workout_plans',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<List<WorkoutPlan>> getWorkoutPlans() async {
    final db = await database;
    final result = await db.query('workout_plans');
    return result.map((map) => WorkoutPlan.fromMap(map)).toList();
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getExercises() async {
    final db = await database;
    final result = await db.query('exercises');
    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<Exercise?> getExercise(int id) async {
    final db = await database;
    final result = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Exercise.fromMap(result.first);
  }
}
