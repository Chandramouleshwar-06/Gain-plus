/// Formats a weight without a trailing ".0": 80 -> "80", 82.5 -> "82.5".
String formatWeight(double weight) =>
    weight == weight.roundToDouble() ? weight.toInt().toString() : weight.toString();

/// Training volume: "975 kg" below a tonne, "12.4 t" above.
String formatVolume(double kg) => kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)} t' : '${kg.round()} kg';

/// Workout length: "<1 min", "45 min", "1 h 20 min".
String formatDuration(int seconds) {
  if (seconds < 60) return '<1 min';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}

/// Parses a typed number. A comma is a decimal point ("82,5" = 82.5)
/// unless it groups thousands ("1,200" = 1200, "12,500.5" = 12500.5).
double? parseDecimal(String text) {
  var s = text.trim().replaceAll(' ', '');
  if (s.contains('.') || RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)) {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}
