import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';

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

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Android 13+ requires asking for notification permission at runtime.
    await _android?.requestNotificationsPermission();
  }

  String _getCustomMessage(String planName) {
    final name = planName.toLowerCase();

    final legMessages = [
      "No more chicken legs, go train!",
      "Friends don't let friends skip leg day.",
      "The squats are calling and I must go.",
      "Today's forecast: 100% chance of pain."
    ];

    final chestMessages = [
      "Time to build that armor plating.",
      "International Chest Day is every day.",
      "Bench more, worry less."
    ];

    final backMessages = [
      "Wings are made in the gym, not at KFC.",
      "Building a back like a cobra.",
      "Pull day = Best day."
    ];

    final generalMessages = [
      "Your workout is waiting for you!",
      "Don't wish for it, work for it.",
      "Excuses don't burn calories.",
      "The only bad workout is the one that didn't happen."
    ];

    if (name.contains('leg')) return legMessages[Random().nextInt(legMessages.length)];
    if (name.contains('chest') || name.contains('push')) return chestMessages[Random().nextInt(chestMessages.length)];
    if (name.contains('back') || name.contains('pull')) return backMessages[Random().nextInt(backMessages.length)];

    return generalMessages[Random().nextInt(generalMessages.length)];
  }

  /// Schedules a reminder. Returns false if [scheduledTime] is already in the
  /// past, since the plugin rejects past dates.
  Future<bool> scheduleWorkoutReminder(int id, String planName, DateTime scheduledTime) async {
    final when = tz.TZDateTime.from(scheduledTime, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return false;

    final message = _getCustomMessage(planName);

    // Exact alarms need a user-granted permission on Android 14+. Without it,
    // fall back to inexact scheduling, which may fire a few minutes late.
    final canScheduleExact = await _android?.canScheduleExactNotifications() ?? true;

    await _notifications.zonedSchedule(
      id,
      'Workout Time: $planName',
      message,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_reminders',
          'Workout Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
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
