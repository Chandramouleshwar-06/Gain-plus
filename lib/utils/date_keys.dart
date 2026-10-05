/// Key used to store a scheduled plan for a calendar day in the `schedules` table.
String scheduleDateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

/// Notification ID for a day's workout reminder (yyyymmdd), one reminder per day.
int reminderIdForDate(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
