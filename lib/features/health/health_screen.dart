import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/health_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../activity/activities_screen.dart';
import '../activity/activity_provider.dart';
import '../nutrition/nutrition_provider.dart';
import '../profile/profile_provider.dart';
import 'health_provider.dart';

/// Refreshes health data, then reloads what imports can change.
Future<int> syncHealth(BuildContext context) async {
  final health = context.read<HealthProvider>();
  final profile = context.read<ProfileProvider>();
  final activity = context.read<ActivityProvider>();
  final nutrition = context.read<NutritionProvider>();
  await health.ready;
  if (!context.mounted) return 0;
  if (!health.connected) return 0;
  final imported = await health.refresh(body: bodyMetricsOf(profile));
  await Future.wait([activity.load(), profile.load(), nutrition.load()]);
  return imported;
}

/// Connects Health Connect and asks for access, then imports.
Future<void> connectHealth(BuildContext context) async {
  final health = context.read<HealthProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final wasInstalled = health.status == HealthStatus.available;
  final connected = await health.connect();
  if (!context.mounted) return;
  if (!connected) {
    if (!wasInstalled && health.status != HealthStatus.unsupported) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Install or update Health Connect, then come back and connect.')));
    } else if (health.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(health.error!)));
    }
    return;
  }
  final imported = await syncHealth(context);
  messenger.showSnackBar(SnackBar(
      content: Text(imported == 0 ? 'Connected to Health Connect.' : 'Connected. Imported $imported activities.')));
}

/// Steps, calories, heart rate and sleep from Health Connect.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncHealth(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final today = health.today;

    return Scaffold(
      appBar: AppBar(title: Text('HEALTH', style: AppText.display(22))),
      body: RefreshIndicator(
        color: AppColors.lime,
        onRefresh: () => syncHealth(context),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            if (!health.connected)
              const HealthConnectCard()
            else ...[
              Row(
                children: [
                  Expanded(child: _Metric(icon: Icons.directions_walk_rounded, label: 'STEPS', value: _int(today?.steps))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                        icon: Icons.local_fire_department_rounded,
                        label: 'ACTIVE KCAL',
                        value: _int(today?.activeKcal?.round())),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.favorite_rounded,
                      label: 'RESTING HR',
                      value: today?.restingHeartRate == null ? '-' : '${today!.restingHeartRate!.round()} bpm',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      icon: Icons.bedtime_rounded,
                      label: 'SLEEP',
                      value: today?.sleep == null ? '-' : formatDuration(today!.sleep!.inSeconds),
                    ),
                  ),
                ],
              ),
              if (today?.averageHeartRate != null) ...[
                const SizedBox(height: 8),
                Text('Average heart rate today: ${today!.averageHeartRate!.round()} bpm', style: AppText.muted),
              ],
              const SizedBox(height: 20),
              const SectionHeader(title: 'Steps this week'),
              AppCard(child: _StepsChart(days: health.weekSteps)),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivitiesScreen())),
                child: const Row(
                  children: [
                    Icon(Icons.sync_alt_rounded, color: AppColors.lime),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Workouts from Health Connect show up in your activities. '
                        'Activities and gym workouts you log here are saved to Health Connect.',
                        style: AppText.muted,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                health.busy
                    ? 'Updating...'
                    : health.lastSynced == null
                        ? ''
                        : 'Updated ${DateFormat('h:mm a').format(health.lastSynced!)}',
                style: AppText.muted,
              ),
              if (health.error != null) Text(health.error!, style: const TextStyle(color: AppColors.orange)),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Disconnect',
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Disconnect Health Connect?',
                    message: 'Gain+ will stop reading and writing health data. Activities already imported stay.',
                    confirmLabel: 'Disconnect',
                    destructive: true,
                  );
                  if (ok && context.mounted) await context.read<HealthProvider>().disconnect();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _int(int? v) => v == null ? '-' : NumberFormat.decimalPattern().format(v);
}

/// Explains the Health Connect link and offers to connect.
class HealthConnectCard extends StatelessWidget {
  const HealthConnectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final (title, message, button) = switch (health.status) {
      HealthStatus.unsupported => (
          'Health apps',
          'Apple Health support is coming soon. Health Connect works on Android.',
          null,
        ),
      HealthStatus.notInstalled => (
          'Health Connect',
          'Install Health Connect to bring in steps, sleep, heart rate and workouts from your watch and other apps.',
          'Install Health Connect',
        ),
      HealthStatus.needsUpdate => (
          'Health Connect',
          'Health Connect needs an update before Gain+ can use it.',
          'Update Health Connect',
        ),
      HealthStatus.available => (
          'Health Connect',
          'See steps, sleep and heart rate here, bring in runs and rides from your watch, '
              'and save your Gain+ workouts to Health Connect. You choose what to share.',
          'Connect',
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_rounded, color: AppColors.lime),
              const SizedBox(width: 10),
              Expanded(child: Text(title.toUpperCase(), style: AppText.display(22))),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppText.muted),
          if (button != null) ...[
            const SizedBox(height: 14),
            PrimaryButton(text: button, onPressed: health.busy ? null : () => connectHealth(context)),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.lime, size: 22),
          const SizedBox(height: 8),
          Text(label, style: AppText.eyebrow),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.display(28)),
          ),
        ],
      ),
    );
  }
}

/// Seven bars, today highlighted.
class _StepsChart extends StatelessWidget {
  final List<(DateTime, int)> days;
  const _StepsChart({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('No step data yet.', style: AppText.muted);
    final peak = days.fold(0, (m, d) => d.$2 > m ? d.$2 : m);
    return Semantics(
      label: 'Steps per day: ${days.map((d) => '${DateFormat('EEEE').format(d.$1)} ${d.$2}').join(', ')}',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        days[i].$2 >= 1000 ? '${(days[i].$2 / 1000).toStringAsFixed(1)}k' : '${days[i].$2}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: peak == 0 ? 0.02 : (days[i].$2 / peak).clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == days.length - 1 ? AppColors.lime : AppColors.lime.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(DateFormat('E').format(days[i].$1).substring(0, 1),
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Profile row: Health Connect status, opens the Health screen.
class HealthLinkTile extends StatelessWidget {
  const HealthLinkTile({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen())),
      child: Row(
        children: [
          const Icon(Icons.monitor_heart_rounded, color: AppColors.lime),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Health Connect', style: AppText.strong),
                Text(
                  health.connected
                      ? 'Connected · steps, sleep, heart rate, workouts'
                      : health.status == HealthStatus.unsupported
                          ? 'Not available on this phone yet'
                          : 'Not connected',
                  style: AppText.muted,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Home card with today's steps and sleep, when connected.
class HealthTodayCard extends StatelessWidget {
  const HealthTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    if (!health.connected) return const SizedBox.shrink();
    final today = health.today;
    final parts = [
      if (today?.steps != null) '${NumberFormat.decimalPattern().format(today!.steps)} steps',
      if (today?.sleep != null) '${formatDuration(today!.sleep!.inSeconds)} sleep',
      if (today?.restingHeartRate != null) '${today!.restingHeartRate!.round()} bpm resting',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen())),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.monitor_heart_rounded, color: AppColors.lime),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HEALTH TODAY', style: AppText.eyebrow),
                  const SizedBox(height: 2),
                  Text(parts.isEmpty ? 'Pull down to update' : parts.join(' · '), style: AppText.strong, maxLines: 2),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
