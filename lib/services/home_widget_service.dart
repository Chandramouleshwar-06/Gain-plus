import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../utils/date_keys.dart';

/// What the home-screen widget shows. It covers the next week, so the
/// widget stays right after midnight even if the app isn't opened:
/// the Android side picks today's entry and works out the streak itself.
Map<String, Object> buildHomeWidgetData({
  required DateTime now,
  required Iterable<DateTime> workoutDates,
  required (String, int)? Function(DateTime day) planFor,
  required int weeklyTarget,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final recent = workoutDates
      .map((d) => DateTime(d.year, d.month, d.day))
      .where((d) => !d.isBefore(today.subtract(const Duration(days: 120))))
      .toSet()
      .toList()
    ..sort();
  final data = <String, Object>{
    'workout_days': recent.map(dateKey).join(','),
    'weekly_target': weeklyTarget,
  };
  for (var i = 0; i < 8; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final plan = planFor(day);
    data['plan_${dateKey(day)}'] = plan == null ? '' : '${plan.$1}|${plan.$2}';
  }
  return data;
}

/// Sends [buildHomeWidgetData] output to the Android widget.
class HomeWidgetService {
  static final HomeWidgetService instance = HomeWidgetService._();
  HomeWidgetService._();

  static const androidProvider = 'GainPlusWidgetProvider';

  Map<String, Object>? _last;

  Future<void> update(Map<String, Object> data) async {
    if (kIsWeb || !Platform.isAndroid || mapEquals(data, _last)) return;
    try {
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(androidName: androidProvider);
      _last = data;
    } catch (e) {
      debugPrint('Could not update home widget: $e');
    }
  }
}
