import '../utils/date_keys.dart';

/// The user's profile. There is one per user, with a fixed ID so it syncs
/// as a single row.
class Profile {
  static const singletonId = 'profile';

  final String name;

  /// 'kg' or 'lb'. Weights are always stored in kg; this is display only.
  final String units;

  /// 'beginner', 'intermediate' or 'advanced'.
  final String? experience;
  final int? birthYear;
  final double? heightCm;
  final int workoutsPerWeek;

  /// 'build_muscle', 'lose_fat', 'get_stronger' or 'general_fitness'.
  final String? primaryGoal;

  /// When onboarding was finished; null until then.
  final DateTime? onboardedAt;

  const Profile({
    this.name = '',
    this.units = 'kg',
    this.experience,
    this.birthYear,
    this.heightCm,
    this.workoutsPerWeek = 3,
    this.primaryGoal,
    this.onboardedAt,
  });

  Profile copyWith({
    String? name,
    String? units,
    String? experience,
    int? birthYear,
    double? heightCm,
    int? workoutsPerWeek,
    String? primaryGoal,
    DateTime? onboardedAt,
  }) {
    return Profile(
      name: name ?? this.name,
      units: units ?? this.units,
      experience: experience ?? this.experience,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      onboardedAt: onboardedAt ?? this.onboardedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': singletonId,
      'name': name,
      'units': units,
      'experience': experience,
      'birthYear': birthYear,
      'heightCm': heightCm,
      'workoutsPerWeek': workoutsPerWeek,
      'primaryGoal': primaryGoal,
      'onboardedAt': onboardedAt?.millisecondsSinceEpoch,
    };
  }

  factory Profile.fromMap(Map<String, Object?> map) {
    final onboardedAt = map['onboardedAt'] as int?;
    return Profile(
      name: map['name'] as String,
      units: map['units'] as String,
      experience: map['experience'] as String?,
      birthYear: map['birthYear'] as int?,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      workoutsPerWeek: map['workoutsPerWeek'] as int,
      primaryGoal: map['primaryGoal'] as String?,
      onboardedAt: onboardedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(onboardedAt),
    );
  }
}

class Goal {
  /// Lift a target weight on [Goal.exerciseId].
  static const typeLift = 'lift';

  /// Train a target number of times per week.
  static const typeFrequency = 'frequency';

  /// Reach a target body weight.
  static const typeBodyWeight = 'body_weight';

  final String id;
  final String type;
  final String? exerciseId;
  final double targetValue;
  final double? startValue;
  final DateTime? deadline;
  final DateTime? achievedAt;

  Goal({
    required this.id,
    required this.type,
    this.exerciseId,
    required this.targetValue,
    this.startValue,
    this.deadline,
    this.achievedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'exerciseId': exerciseId,
      'targetValue': targetValue,
      'startValue': startValue,
      'deadline': deadline == null ? null : dateKey(deadline!),
      'achievedAt': achievedAt?.millisecondsSinceEpoch,
    };
  }

  factory Goal.fromMap(Map<String, Object?> map) {
    final deadline = map['deadline'] as String?;
    final achievedAt = map['achievedAt'] as int?;
    return Goal(
      id: map['id'] as String,
      type: map['type'] as String,
      exerciseId: map['exerciseId'] as String?,
      targetValue: (map['targetValue'] as num).toDouble(),
      startValue: (map['startValue'] as num?)?.toDouble(),
      deadline: deadline == null ? null : parseDateKey(deadline),
      achievedAt: achievedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(achievedAt),
    );
  }
}

class BodyWeightEntry {
  final String id;
  final DateTime date;
  final double weightKg;

  /// 'manual' or 'health' (imported from Health Connect / HealthKit).
  final String source;

  BodyWeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.source = 'manual',
  });

  factory BodyWeightEntry.fromMap(Map<String, Object?> map) {
    return BodyWeightEntry(
      id: map['id'] as String,
      date: parseDateKey(map['date'] as String),
      weightKg: (map['weightKg'] as num).toDouble(),
      source: map['source'] as String,
    );
  }
}
