import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../theme/app_theme.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Without this, tz.local stays UTC and reminders fire at the wrong local time.
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (e) {
      debugPrint('Could not determine local timezone, falling back to UTC: $e');
    }

    // White silhouette: Android draws status-bar icons as a mask.
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_gainplus');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Android 13+ requires asking for notification permission at runtime.
    await _android?.requestNotificationsPermission();
  }

  /// Schedules a reminder. Returns false if [scheduledTime] is already in the
  /// past, since the plugin rejects past dates.
  Future<bool> scheduleReminder(
    int id,
    String title,
    String body,
    DateTime scheduledTime, {
    ReminderChannel channel = ReminderChannel.workouts,
  }) async {
    final when = tz.TZDateTime.from(scheduledTime, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return false;

    // Exact alarms need a user-granted permission on Android 14+. Without it,
    // fall back to inexact scheduling, which may fire a few minutes late.
    final canScheduleExact = await _android?.canScheduleExactNotifications() ?? true;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.title,
          channelDescription: channel.description,
          importance: channel == ReminderChannel.workouts ? Importance.max : Importance.defaultImportance,
          priority: channel == ReminderChannel.workouts ? Priority.high : Priority.defaultPriority,
          color: AppColors.lime,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
  }

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }

  /// Fixed ID so a new rest replaces the previous one.
  static const _restOverId = 900001;

  /// Alerts when rest is over, even with the phone locked.
  Future<void> scheduleRestOver(DateTime at) async {
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    final canScheduleExact = await _android?.canScheduleExactNotifications() ?? true;

    await _notifications.zonedSchedule(
      _restOverId,
      'Rest over',
      'Time for your next set.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Tells you when rest between sets is over',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          color: AppColors.lime,
          timeoutAfter: 60000,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelRestOver() => _notifications.cancel(_restOverId);
}

/// Android notification channels, so each kind can be muted separately in
/// the phone's settings.
enum ReminderChannel {
  workouts('workout_reminders', 'Workout reminders', 'Reminders for workouts you scheduled'),
  motivation('motivation', 'Motivation', 'Streak alerts, weekly target check-ins and nudges'),
  recap('weekly_recap', 'Weekly recap', 'Your training summary every Sunday');

  const ReminderChannel(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}
