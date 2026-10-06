class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String notes;
  final bool isCustom;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.notes,
    this.isCustom = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'notes': notes,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  factory Exercise.fromMap(Map<String, Object?> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      muscleGroup: map['muscleGroup'] as String,
      notes: map['notes'] as String,
      isCustom: map['isCustom'] == 1,
    );
  }
}
