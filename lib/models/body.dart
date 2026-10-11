/// A place on the body that's measured. Lengths are stored in cm; body fat
/// is a percentage.
class MeasurementSite {
  final String code;
  final String label;
  final bool isPercent;

  /// True when bigger is the usual aim (arms), false when smaller is
  /// (waist), null when either.
  final bool? growthIsGood;

  const MeasurementSite(this.code, this.label, {this.isPercent = false, this.growthIsGood});
}

const measurementSites = [
  MeasurementSite('waist', 'Waist', growthIsGood: false),
  MeasurementSite('chest', 'Chest'),
  MeasurementSite('hips', 'Hips'),
  MeasurementSite('neck', 'Neck'),
  MeasurementSite('arm', 'Arm (flexed)', growthIsGood: true),
  MeasurementSite('forearm', 'Forearm', growthIsGood: true),
  MeasurementSite('thigh', 'Thigh', growthIsGood: true),
  MeasurementSite('calf', 'Calf', growthIsGood: true),
  MeasurementSite('body_fat', 'Body fat', isPercent: true, growthIsGood: false),
];

MeasurementSite? measurementSite(String? code) => measurementSites.where((s) => s.code == code).firstOrNull;

class BodyMeasurement {
  final String id;
  final DateTime date;
  final String site;
  final double value;

  const BodyMeasurement({required this.id, required this.date, required this.site, required this.value});
}

/// A progress photo, kept on this phone only.
class ProgressPhoto {
  final String id;
  final DateTime date;

  /// 'front', 'side' or 'back'.
  final String pose;
  final String path;

  const ProgressPhoto({required this.id, required this.date, required this.pose, required this.path});
}

const photoPoses = ['front', 'side', 'back'];

String poseLabel(String pose) => switch (pose) {
      'side' => 'Side',
      'back' => 'Back',
      _ => 'Front',
    };
