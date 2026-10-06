/// Formats a weight without a trailing ".0": 80 -> "80", 82.5 -> "82.5".
String formatWeight(double weight) =>
    weight == weight.roundToDouble() ? weight.toInt().toString() : weight.toString();
