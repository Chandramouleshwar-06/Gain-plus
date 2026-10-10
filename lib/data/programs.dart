/// Ready-made training programs. Installing one creates a plan per day.
library;

class ProgramExercise {
  /// Must match a built-in exercise name in seed_data.dart.
  final String name;
  final int sets;
  final int? reps;

  const ProgramExercise(this.name, this.sets, [this.reps]);
}

class ProgramDay {
  final String name;
  final List<ProgramExercise> exercises;

  const ProgramDay(this.name, this.exercises);
}

class Program {
  final String id;
  final String name;
  final String level;
  final String summary;

  /// Weekdays to train by default (1 = Monday ... 7 = Sunday). Days rotate
  /// through [days] in order.
  final List<int> defaultWeekdays;
  final List<ProgramDay> days;

  const Program({
    required this.id,
    required this.name,
    required this.level,
    required this.summary,
    required this.defaultWeekdays,
    required this.days,
  });
}

const programs = [
  Program(
    id: 'beginner-full-body',
    name: 'Beginner Full Body',
    level: 'Beginner',
    summary: 'Two alternating full-body sessions, three days a week. The best place to start.',
    defaultWeekdays: [1, 3, 5],
    days: [
      ProgramDay('Full Body A', [
        ProgramExercise('Squat (Barbell)', 3, 8),
        ProgramExercise('Bench Press (Barbell)', 3, 8),
        ProgramExercise('Barbell Row', 3, 8),
        ProgramExercise('Lateral Raise (Dumbbell)', 2, 12),
        ProgramExercise('Plank', 3),
      ]),
      ProgramDay('Full Body B', [
        ProgramExercise('Deadlift (Barbell)', 3, 5),
        ProgramExercise('Overhead Press (Barbell)', 3, 8),
        ProgramExercise('Lat Pulldown', 3, 10),
        ProgramExercise('Lunges (Dumbbell)', 2, 10),
        ProgramExercise('Bicep Curl (Dumbbell)', 2, 12),
      ]),
    ],
  ),
  Program(
    id: 'strength-5x5',
    name: '5×5 Strength',
    level: 'Beginner',
    summary: 'Heavy compound lifts for five sets of five. Add weight every session you complete all reps.',
    defaultWeekdays: [1, 3, 5],
    days: [
      ProgramDay('5×5 Workout A', [
        ProgramExercise('Squat (Barbell)', 5, 5),
        ProgramExercise('Bench Press (Barbell)', 5, 5),
        ProgramExercise('Barbell Row', 5, 5),
      ]),
      ProgramDay('5×5 Workout B', [
        ProgramExercise('Squat (Barbell)', 5, 5),
        ProgramExercise('Overhead Press (Barbell)', 5, 5),
        ProgramExercise('Deadlift (Barbell)', 1, 5),
      ]),
    ],
  ),
  Program(
    id: 'push-pull-legs',
    name: 'Push / Pull / Legs',
    level: 'Intermediate',
    summary: 'Each muscle group trained twice a week across six sessions. Drop to three days if you need more rest.',
    defaultWeekdays: [1, 2, 3, 4, 5, 6],
    days: [
      ProgramDay('PPL Push', [
        ProgramExercise('Bench Press (Barbell)', 4, 6),
        ProgramExercise('Overhead Press (Barbell)', 3, 8),
        ProgramExercise('Incline Bench Press (Barbell)', 3, 10),
        ProgramExercise('Lateral Raise (Dumbbell)', 3, 15),
        ProgramExercise('Tricep Pushdown (Cable)', 3, 12),
      ]),
      ProgramDay('PPL Pull', [
        ProgramExercise('Deadlift (Barbell)', 3, 5),
        ProgramExercise('Pull Up', 3, 8),
        ProgramExercise('Seated Cable Row', 3, 10),
        ProgramExercise('Rear Delt Fly (Machine)', 3, 15),
        ProgramExercise('Hammer Curl (Dumbbell)', 3, 12),
      ]),
      ProgramDay('PPL Legs', [
        ProgramExercise('Squat (Barbell)', 4, 6),
        ProgramExercise('Leg Press', 3, 10),
        ProgramExercise('Leg Curl', 3, 12),
        ProgramExercise('Bulgarian Split Squats', 3, 10),
        ProgramExercise('Calf Raise', 4, 15),
      ]),
    ],
  ),
  Program(
    id: 'upper-lower',
    name: 'Upper / Lower',
    level: 'Intermediate',
    summary: 'Four sessions a week alternating upper and lower body. Good balance of strength and size.',
    defaultWeekdays: [1, 2, 4, 5],
    days: [
      ProgramDay('Upper', [
        ProgramExercise('Bench Press (Barbell)', 4, 8),
        ProgramExercise('Barbell Row', 4, 8),
        ProgramExercise('Shoulder Press (Dumbbell)', 3, 10),
        ProgramExercise('Lat Pulldown', 3, 10),
        ProgramExercise('Skull Crushers', 2, 12),
        ProgramExercise('Bicep Curl (Dumbbell)', 2, 12),
      ]),
      ProgramDay('Lower', [
        ProgramExercise('Squat (Barbell)', 4, 8),
        ProgramExercise('Deadlift (Barbell)', 3, 5),
        ProgramExercise('Leg Extension', 3, 12),
        ProgramExercise('Leg Curl', 3, 12),
        ProgramExercise('Calf Raise', 4, 15),
      ]),
    ],
  ),
  Program(
    id: 'calisthenics',
    name: 'Calisthenics Foundations',
    level: 'Beginner',
    summary: 'No equipment beyond a bar. Build strength with your own body weight, three days a week.',
    defaultWeekdays: [2, 4, 6],
    days: [
      ProgramDay('Calisthenics', [
        ProgramExercise('Push Ups', 3, 12),
        ProgramExercise('Australian Pull Ups', 3, 10),
        ProgramExercise('Pike Push Ups', 3, 8),
        ProgramExercise('Pull Up', 3, 5),
        ProgramExercise('Bulgarian Split Squats', 3, 10),
        ProgramExercise('Hollow Body Hold', 3),
      ]),
    ],
  ),
];
