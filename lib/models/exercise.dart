import '../data/equipment.dart';

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String notes;
  final bool isCustom;

  /// Equipment codes it needs (see [Equipment]); empty = bodyweight.
  final List<String> equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.notes,
    this.isCustom = false,
    this.equipment = const [],
  });

  /// The main muscle group, e.g. "Back" for "Back/Biceps".
  String get primaryMuscle => muscleGroup.split('/').first.trim();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'notes': notes,
      'isCustom': isCustom ? 1 : 0,
      'equipment': equipment.join(','),
    };
  }

  factory Exercise.fromMap(Map<String, Object?> map) {
    final isCustom = map['isCustom'] == 1;
    final name = map['name'] as String;
    return Exercise(
      id: map['id'] as String,
      name: name,
      muscleGroup: map['muscleGroup'] as String,
      notes: map['notes'] as String,
      isCustom: isCustom,
      // Built-ins take their equipment from code so it stays current.
      equipment: isCustom
          ? ((map['equipment'] as String?) ?? '').split(',').where((s) => s.isNotEmpty).toList()
          : builtinEquipment[name] ?? const [],
    );
  }
}
