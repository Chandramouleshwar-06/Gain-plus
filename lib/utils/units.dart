import 'format.dart';

/// Converts and formats weights for the user's chosen unit. Everything is
/// stored in kg; this only affects what's shown and typed.
class Units {
  static const kgPerLb = 0.45359237;

  final bool isLb;

  const Units({this.isLb = false});

  const Units.kg() : isLb = false;
  const Units.lb() : isLb = true;

  factory Units.fromCode(String? code) => code == 'lb' ? const Units.lb() : const Units.kg();

  String get code => isLb ? 'lb' : 'kg';
  String get label => code;

  /// kg to the display unit.
  double fromKg(double kg) => isLb ? kg / kgPerLb : kg;

  /// Display unit to kg.
  double toKg(double value) => isLb ? value * kgPerLb : value;

  /// "82.5" (no unit), rounded to 0.1 so lb round-trips cleanly.
  String number(double kg) => formatWeight((fromKg(kg) * 10).roundToDouble() / 10);

  /// "82.5 kg" / "180 lb".
  String weight(double kg) => '${number(kg)} $label';

  /// Training volume: "975 kg", "12.4 t" or "2,150 lb", "27.3k lb".
  String volume(double kg) {
    final v = fromKg(kg);
    if (isLb) return v >= 10000 ? '${(v / 1000).toStringAsFixed(1)}k lb' : '${v.round()} lb';
    return formatVolume(kg);
  }

  static const cmPerInch = 2.54;

  /// Body measurements follow the weight unit: cm with kg, inches with lb.
  String get lengthLabel => isLb ? 'in' : 'cm';

  double fromCm(double cm) => isLb ? cm / cmPerInch : cm;
  double toCm(double value) => isLb ? value * cmPerInch : value;

  /// "81.5" (no unit), rounded to 0.1.
  String lengthNumber(double cm) => formatWeight((fromCm(cm) * 10).roundToDouble() / 10);

  /// "81.5 cm" / "32.1 in".
  String length(double cm) => '${lengthNumber(cm)} $lengthLabel';

  /// Weight to add when progressing: small for upper body, big for legs.
  double increment({required bool lowerBody}) => isLb ? (lowerBody ? 10 : 5) : (lowerBody ? 5 : 2.5);
}
