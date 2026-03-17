import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
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

  Future<void> scheduleWorkoutReminder(int id, String planName, DateTime scheduledTime) async {
    final message = _getCustomMessage(planName);
    
    await _notifications.zonedSchedule(
      id,
      'Workout Time: $planName',
      message,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_reminders',
          'Workout Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }
}
