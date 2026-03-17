class Exercise {
  final int? id;
  final String name;
  final String muscleGroup;
  final String notes;

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'notes': notes,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      muscleGroup: map['muscleGroup'],
      notes: map['notes'],
    );
  }
}
