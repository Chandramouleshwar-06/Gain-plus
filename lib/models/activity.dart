/// A non-gym activity: a run, a swim, a game of football.
class Activity {
  final String id;

  /// An [ActivityType] code, e.g. 'running'.
  final String type;
  final DateTime startedAt;
  final int durationSeconds;
  final double? distanceMeters;
  final double kcal;
  final String notes;

  /// 'manual', or 'health' when imported from Health Connect / Apple Health.
  final String source;

  /// The health record it was imported from, so it's only imported once.
  final String? externalId;

  const Activity({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.durationSeconds,
    this.distanceMeters,
    required this.kcal,
    this.notes = '',
    this.source = 'manual',
    this.externalId,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'kcal': kcal,
        'notes': notes,
        'source': source,
        'externalId': externalId,
      };

  factory Activity.fromMap(Map<String, Object?> map) => Activity(
        id: map['id'] as String,
        type: map['type'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        durationSeconds: map['durationSeconds'] as int,
        distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
        kcal: (map['kcal'] as num).toDouble(),
        notes: map['notes'] as String? ?? '',
        source: map['source'] as String? ?? 'manual',
        externalId: map['externalId'] as String?,
      );
}
