/// Calendar-day key stored in the database, e.g. `2026-01-05`.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Parses a [dateKey] back to a local date. Also accepts the unpadded
/// `2026-1-5` keys that older versions stored.
DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// Notification ID for a day's workout reminder (yyyymmdd), one reminder per day.
int reminderIdForDate(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
