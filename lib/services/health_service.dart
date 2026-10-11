import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Whether the phone's health store can be used.
enum HealthStatus {
  /// Not Android or iOS (or iOS, until HealthKit is set up).
  unsupported,

  /// Android without the Health Connect app.
  notInstalled,

  /// Health Connect is installed but needs an update.
  needsUpdate,
  available,
}

/// An exercise session from the health store.
class HealthWorkoutRecord {
  final String id;

  /// A [HealthWorkoutActivityType] name, e.g. 'RUNNING'.
  final String type;
  final DateTime start;
  final DateTime end;
  final double? kcal;
  final double? distanceMeters;

  /// The app that recorded it (package name on Android).
  final String source;

  const HealthWorkoutRecord({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    this.kcal,
    this.distanceMeters,
    this.source = '',
  });
}

/// One day's numbers from the health store. Anything can be missing.
class HealthDaySummary {
  final int? steps;
  final double? activeKcal;
  final double? restingHeartRate;
  final double? averageHeartRate;

  /// Sleep in the night before (sessions ending between 6 pm the day
  /// before and noon).
  final Duration? sleep;

  const HealthDaySummary({this.steps, this.activeKcal, this.restingHeartRate, this.averageHeartRate, this.sleep});
}

/// Reads and writes Health Connect (and later Apple Health).
abstract class HealthService {
  Future<HealthStatus> status();
  Future<void> install();
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<void> revokePermissions();
  Future<HealthDaySummary> day(DateTime day);
  Future<int?> steps(DateTime start, DateTime end);
  Future<List<HealthWorkoutRecord>> workouts(DateTime start, DateTime end);

  /// The newest weight on or after [since], in kg.
  Future<(DateTime, double)?> latestWeight(DateTime since);

  Future<bool> writeWorkout({
    required String type,
    required DateTime start,
    required DateTime end,
    double? kcal,
    double? distanceMeters,
    String? title,
  });
}

/// [HealthService] on top of the `health` plugin.
class PluginHealthService implements HealthService {
  final _health = Health();
  bool _configured = false;

  // Workouts read their distance, calories and steps too, so those need
  // read access; writing a workout also writes its distance and calories.
  static const _readWrite = [
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];
  static const _readOnly = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
  ];

  List<HealthDataType> get _types => [..._readWrite, ..._readOnly];
  List<HealthDataAccess> get _access => [
        for (final _ in _readWrite) HealthDataAccess.READ_WRITE,
        for (final _ in _readOnly) HealthDataAccess.READ,
      ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthStatus> status() async {
    // Apple Health comes later: it needs the HealthKit capability in Xcode.
    if (kIsWeb || !Platform.isAndroid) return HealthStatus.unsupported;
    await _configure();
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => HealthStatus.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HealthStatus.needsUpdate,
      _ => HealthStatus.notInstalled,
    };
  }

  @override
  Future<void> install() async {
    await _configure();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> hasPermissions() async {
    await _configure();
    return await _health.hasPermissions(_types, permissions: _access) ?? false;
  }

  @override
  Future<bool> requestPermissions() async {
    await _configure();
    return _health.requestAuthorization(_types, permissions: _access);
  }

  @override
  Future<void> revokePermissions() async {
    await _configure();
    await _health.revokePermissions();
  }

  Future<List<HealthDataPoint>> _read(HealthDataType type, DateTime start, DateTime end) async {
    try {
      return await _health.getHealthDataFromTypes(types: [type], startTime: start, endTime: end);
    } catch (e) {
      debugPrint('Health: could not read $type: $e');
      return [];
    }
  }

  static double? _numeric(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : null;
  }

  @override
  Future<int?> steps(DateTime start, DateTime end) async {
    await _configure();
    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (e) {
      debugPrint('Health: could not read steps: $e');
      return null;
    }
  }

  @override
  Future<HealthDaySummary> day(DateTime day) async {
    await _configure();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final now = DateTime.now();
    final until = end.isAfter(now) ? now : end;

    final active = await _read(HealthDataType.ACTIVE_ENERGY_BURNED, start, until);
    final resting = await _read(HealthDataType.RESTING_HEART_RATE, start.subtract(const Duration(days: 1)), until);
    final heart = await _read(HealthDataType.HEART_RATE, start, until);
    final sleep = await _read(
        HealthDataType.SLEEP_SESSION, start.subtract(const Duration(hours: 30)), start.add(const Duration(hours: 12)));

    double? sum(List<HealthDataPoint> points) =>
        points.isEmpty ? null : points.map(_numeric).whereType<double>().fold<double>(0, (a, b) => a + b);
    final heartValues = heart.map(_numeric).whereType<double>().toList();
    resting.sort((a, b) => a.dateTo.compareTo(b.dateTo));
    final nightStart = start.subtract(const Duration(hours: 6));
    final nightSessions = sleep.where((p) => p.dateTo.isAfter(nightStart) && !p.dateTo.isAfter(start.add(const Duration(hours: 12))));

    return HealthDaySummary(
      steps: await steps(start, until),
      activeKcal: sum(active),
      restingHeartRate: resting.isEmpty ? null : _numeric(resting.last),
      averageHeartRate: heartValues.isEmpty ? null : heartValues.reduce((a, b) => a + b) / heartValues.length,
      sleep: nightSessions.isEmpty
          ? null
          : nightSessions.fold<Duration>(Duration.zero, (total, p) => total + p.dateTo.difference(p.dateFrom)),
    );
  }

  @override
  Future<List<HealthWorkoutRecord>> workouts(DateTime start, DateTime end) async {
    await _configure();
    final points = await _read(HealthDataType.WORKOUT, start, end);
    return [
      for (final p in points)
        if (p.value is WorkoutHealthValue)
          HealthWorkoutRecord(
            id: p.uuid,
            type: (p.value as WorkoutHealthValue).workoutActivityType.name,
            start: p.dateFrom,
            end: p.dateTo,
            kcal: (p.value as WorkoutHealthValue).totalEnergyBurned?.toDouble(),
            distanceMeters: (p.value as WorkoutHealthValue).totalDistance?.toDouble(),
            source: p.sourceName,
          ),
    ];
  }

  @override
  Future<(DateTime, double)?> latestWeight(DateTime since) async {
    await _configure();
    final points = await _read(HealthDataType.WEIGHT, since, DateTime.now());
    if (points.isEmpty) return null;
    points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final kg = _numeric(points.last);
    return kg == null ? null : (points.last.dateFrom, kg);
  }

  @override
  Future<bool> writeWorkout({
    required String type,
    required DateTime start,
    required DateTime end,
    double? kcal,
    double? distanceMeters,
    String? title,
  }) async {
    await _configure();
    final activityType =
        HealthWorkoutActivityType.values.where((t) => t.name == type).firstOrNull ?? HealthWorkoutActivityType.OTHER;
    return _health.writeWorkoutData(
      activityType: activityType,
      start: start,
      end: end,
      totalEnergyBurned: kcal?.round(),
      totalDistance: distanceMeters?.round(),
      title: title,
      recordingMethod: RecordingMethod.manual,
    );
  }
}
