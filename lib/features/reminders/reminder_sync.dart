import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/date_keys.dart';
import '../../utils/units.dart';
import '../plans/plans_provider.dart';
import '../profile/profile_provider.dart';
import '../progress/achievement_tracker.dart';
import '../progress/insights.dart';
import '../progress/progress_provider.dart';
import '../settings/settings_provider.dart';
import 'reminder_engine.dart';
import 'reminder_planner.dart';

/// "4 workouts · 12.4 t lifted · 2 PRs" for the weekly recap.
String recapLine(WeekSummary? week, [Units units = const Units.kg()]) {
  if (week == null || week.workouts == 0) return 'No workouts logged this week. Next week is a fresh start.';
  final parts = [
    week.workouts == 1 ? '1 workout' : '${week.workouts} workouts',
    '${units.volume(week.volume)} lifted',
    if (week.newPrs.isNotEmpty) week.newPrs.length == 1 ? '1 PR' : '${week.newPrs.length} PRs',
  ];
  return parts.join(' · ');
}

/// Keeps scheduled notifications in line with the app's data: re-plans
/// (debounced) whenever workouts, schedules, the profile or notification
/// settings change, and when the app comes back to the foreground.
class ReminderSync extends StatefulWidget {
  final Widget child;
  const ReminderSync({super.key, required this.child});

  @override
  State<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends State<ReminderSync> with WidgetsBindingObserver {
  Timer? _debounce;
  String? _lastSignature;
  bool _baselineRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastSignature = null; // the date may have changed
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _replan);
  }

  void _replan() {
    if (!mounted) return;
    final progress = context.read<ProgressProvider>();
    final plans = context.read<PlansProvider>();
    final profile = context.read<ProfileProvider>();
    final settings = context.read<SettingsProvider>();
    if (!progress.loaded || !profile.loaded) return;

    if (!_baselineRecorded) {
      _baselineRecorded = true;
      AchievementTracker.instance.checkNew(achievementStats(progress, profile));
    }

    final schedule = [
      for (final entry in plans.schedules.values)
        if (plans.planById(entry.planId) case final plan?)
          ScheduledDay(parseDateKey(entry.date), plan.name, entry.reminderMinutes),
    ];
    ReminderEngine.instance.replan(
      ReminderInput(
        now: DateTime.now(),
        workoutDates: progress.workoutDates,
        weeklyTarget: profile.weeklyTarget,
        schedule: schedule,
        prefs: settings.reminderPrefs,
        thisWeekRecap: recapLine(progress.thisWeek, profile.units),
      ),
      legacyScheduleDates: schedule.map((s) => s.date).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final plans = context.watch<PlansProvider>();
    final profile = context.watch<ProfileProvider>();
    final settings = context.watch<SettingsProvider>();

    // Only re-plan when something reminders depend on actually changed.
    final signature = [
      progress.workoutDates.length,
      progress.workoutDates.isEmpty ? 0 : progress.workoutDates.reduce((a, b) => a.isAfter(b) ? a : b).millisecondsSinceEpoch,
      progress.thisWeek?.volume,
      for (final e in plans.schedules.values) '${e.date}:${e.planId}:${e.reminderMinutes}',
      for (final p in plans.plans) p.name,
      profile.weeklyTarget,
      settings.reminderPrefs.quietStartHour,
      settings.reminderPrefs.quietEndHour,
      settings.reminderPrefs.dailyCap,
      settings.reminderKinds.toString(),
    ].join('|');
    if (signature != _lastSignature) {
      _lastSignature = signature;
      _schedule();
    }
    return widget.child;
  }
}
