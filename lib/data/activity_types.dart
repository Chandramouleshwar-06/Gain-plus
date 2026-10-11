import 'package:flutter/material.dart';

/// A kind of activity with its energy cost in METs (Compendium of Physical
/// Activities). For distance activities, [speedMets] refines it by speed.
class ActivityType {
  final String code;
  final String label;
  final IconData icon;
  final double met;
  final bool hasDistance;

  /// (km/h, METs) points, interpolated between; outside the range the
  /// nearest end is used.
  final List<(double, double)> speedMets;

  const ActivityType(this.code, this.label, this.icon, this.met, {this.hasDistance = false, this.speedMets = const []});
}

const activityTypes = [
  ActivityType('running', 'Running', Icons.directions_run_rounded, 9.8, hasDistance: true, speedMets: [
    (6.4, 6.0), (8.0, 8.3), (9.7, 9.8), (11.3, 11.0), (12.9, 11.8), (14.5, 12.8), (16.1, 14.5), (17.7, 16.0),
  ]),
  ActivityType('walking', 'Walking', Icons.directions_walk_rounded, 3.5, hasDistance: true, speedMets: [
    (3.2, 2.8), (4.0, 3.0), (4.8, 3.5), (5.6, 4.3), (6.4, 5.0), (7.2, 7.0),
  ]),
  ActivityType('cycling', 'Cycling', Icons.directions_bike_rounded, 7.5, hasDistance: true, speedMets: [
    (12.0, 4.0), (16.0, 6.8), (20.5, 8.0), (23.5, 10.0), (27.0, 12.0), (32.0, 15.8),
  ]),
  ActivityType('swimming', 'Swimming', Icons.pool_rounded, 7.0, hasDistance: true),
  ActivityType('hiking', 'Hiking', Icons.terrain_rounded, 6.0, hasDistance: true),
  ActivityType('hiit', 'HIIT', Icons.local_fire_department_rounded, 8.0),
  ActivityType('yoga', 'Yoga', Icons.self_improvement_rounded, 2.5),
  ActivityType('rowing', 'Rowing', Icons.rowing_rounded, 7.0, hasDistance: true),
  ActivityType('skipping', 'Skipping', Icons.sports_gymnastics_rounded, 11.0),
  ActivityType('elliptical', 'Elliptical', Icons.fitness_center_rounded, 5.0),
  ActivityType('stairs', 'Stair climbing', Icons.stairs_rounded, 8.8),
  ActivityType('football', 'Football', Icons.sports_soccer_rounded, 7.0),
  ActivityType('cricket', 'Cricket', Icons.sports_cricket_rounded, 4.8),
  ActivityType('badminton', 'Badminton', Icons.sports_tennis_rounded, 5.5),
  ActivityType('basketball', 'Basketball', Icons.sports_basketball_rounded, 6.5),
  ActivityType('tennis', 'Tennis', Icons.sports_tennis_rounded, 7.3),
  ActivityType('dancing', 'Dancing', Icons.music_note_rounded, 5.0),
  ActivityType('other', 'Other', Icons.bolt_rounded, 5.0),
];

/// Weight training as a whole session, rests included (Compendium 02054).
const strengthTrainingMet = 3.5;

ActivityType activityType(String code) =>
    activityTypes.where((t) => t.code == code).firstOrNull ?? activityTypes.last;

/// Body weight used when none is logged.
const defaultBodyWeightKg = 70.0;

/// What calorie estimates are personalised with. Anything can be missing.
class BodyMetrics {
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? sex;

  const BodyMetrics({this.weightKg, this.heightCm, this.age, this.sex});

  /// Resting burn per hour. With height, age and sex this is your own
  /// (Mifflin-St Jeor) rather than the textbook 1 kcal per kg per hour.
  double get restingKcalPerHour {
    final weight = weightKg ?? defaultBodyWeightKg;
    if (heightCm == null || age == null || sex == null) return weight;
    final bmr = 10 * weight + 6.25 * heightCm! - 5 * age! + (sex == 'female' ? -161 : 5);
    return bmr / 24;
  }
}

/// METs for [type], refined by speed when distance is known.
double metFor(ActivityType type, {required Duration duration, double? distanceKm}) {
  final points = type.speedMets;
  if (points.isEmpty || distanceKm == null || distanceKm <= 0 || duration.inSeconds <= 0) return type.met;
  final speed = distanceKm / (duration.inSeconds / 3600);
  if (speed <= points.first.$1) return points.first.$2;
  if (speed >= points.last.$1) return points.last.$2;
  for (var i = 1; i < points.length; i++) {
    final (x1, y1) = points[i];
    if (speed <= x1) {
      final (x0, y0) = points[i - 1];
      return y0 + (y1 - y0) * (speed - x0) / (x1 - x0);
    }
  }
  return type.met;
}

/// Estimated calories: METs x resting burn per hour x hours.
double estimateKcal({required double met, required BodyMetrics body, required Duration duration}) =>
    (met * body.restingKcalPerHour * duration.inSeconds / 3600).roundToDouble();
