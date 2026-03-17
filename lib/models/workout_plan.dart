class WorkoutPlan {
  final int? id;
  final String name;
  final List<int> exerciseIds;

  WorkoutPlan({
    this.id,
    required this.name,
    required this.exerciseIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'exerciseIds': exerciseIds.join(','),
    };
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutPlan(
      id: map['id'],
      name: map['name'],
      exerciseIds: (map['exerciseIds'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s))
          .toList(),
    );
  }
}
