import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/activity_types.dart';
import '../../data/sync_columns.dart';
import '../../models/activity.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../health/health_provider.dart';
import '../profile/profile_provider.dart';
import 'activity_provider.dart';

/// Log a run, swim, game or any other activity, or edit one ([existing]).
/// Calories are estimated from the activity, its pace and your body
/// metrics, and can be overridden with a number from a watch.
class LogActivityScreen extends StatefulWidget {
  final Activity? existing;
  final String? initialType;
  const LogActivityScreen({super.key, this.existing, this.initialType});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  late String _type;
  late DateTime _start;
  late final TextEditingController _minutes;
  late final TextEditingController _distance;
  late final TextEditingController _kcal;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _type = a?.type ?? widget.initialType ?? 'running';
    _start = a?.startedAt ?? DateTime.now().subtract(const Duration(minutes: 30));
    _minutes = TextEditingController(text: a == null ? '30' : '${(a.durationSeconds / 60).round()}');
    _distance = TextEditingController(text: a?.distanceMeters == null ? '' : _trim(a!.distanceMeters! / 1000));
    _kcal = TextEditingController(text: a == null ? '' : '${a.kcal.round()}');
    _notes = TextEditingController(text: a?.notes ?? '');
  }

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();
    _kcal.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  ActivityType get _activity => activityType(_type);
  Duration get _duration => Duration(minutes: int.tryParse(_minutes.text.trim()) ?? 0);
  double? get _distanceKm {
    final km = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
    return _activity.hasDistance && km != null && km > 0 ? km : null;
  }

  double _estimate(BodyMetrics body) => estimateKcal(
        met: metFor(_activity, duration: _duration, distanceKm: _distanceKm),
        body: body,
        duration: _duration,
      );

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(_start);
    setState(() => _start = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _save(double estimate) async {
    if (_duration.inMinutes <= 0) return;
    final ownKcal = double.tryParse(_kcal.text.trim());
    final activity = Activity(
      id: widget.existing?.id ?? newId(),
      type: _type,
      startedAt: _start,
      durationSeconds: _duration.inSeconds,
      distanceMeters: _distanceKm == null ? null : _distanceKm! * 1000,
      kcal: ownKcal != null && ownKcal >= 0 ? ownKcal : estimate,
      notes: _notes.text.trim(),
      source: widget.existing?.source ?? 'manual',
      externalId: widget.existing?.externalId,
    );
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      final health = context.read<HealthProvider>();
      await context.read<ActivityProvider>().save(activity);
      // New activities go to Health Connect too (edits would duplicate them).
      if (widget.existing == null) unawaited(health.exportActivity(activity));
      navigator.pop(true);
    } catch (e) {
      debugPrint('Could not save activity: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't save the activity. Please try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = bodyMetricsOf(context.watch<ProfileProvider>());
    final estimate = _estimate(body);
    final personal = body.weightKg != null && body.heightCm != null && body.age != null && body.sex != null;
    final distanceKm = _distanceKm;
    final pace = distanceKm == null || _duration.inSeconds == 0 ? null : _duration.inSeconds / distanceKm;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(text, style: AppText.eyebrow),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'LOG ACTIVITY' : 'EDIT ACTIVITY', style: AppText.display(22)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          label('ACTIVITY'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in activityTypes)
                ChoiceChip(
                  avatar: Icon(t.icon, size: 18, color: t.code == _type ? AppColors.onLime : AppColors.textMuted),
                  label: Text(t.label),
                  selected: t.code == _type,
                  showCheckmark: false,
                  selectedColor: AppColors.lime,
                  labelStyle: TextStyle(color: t.code == _type ? AppColors.onLime : AppColors.text),
                  onSelected: (_) => setState(() => _type = t.code),
                ),
            ],
          ),
          label('WHEN'),
          OutlinedButton.icon(
            onPressed: _pickStart,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(DateFormat('EEE d MMM, h:mm a').format(_start)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
          ),
          label(_activity.hasDistance ? 'DURATION AND DISTANCE' : 'DURATION'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('activity-minutes'),
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_activity.hasDistance) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('activity-distance'),
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Distance (km)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
          if (pace != null) ...[
            const SizedBox(height: 8),
            Text(
              _type == 'swimming' || _type == 'rowing'
                  ? 'Pace ${_formatPace(pace / 10)} per 100 m'
                  : 'Pace ${_formatPace(pace)} per km · ${(distanceKm! / (_duration.inSeconds / 3600)).toStringAsFixed(1)} km/h',
              style: AppText.muted,
            ),
          ],
          label('CALORIES BURNED'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${estimate.round()}', style: AppText.display(40)),
                    const SizedBox(width: 6),
                    const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('kcal estimated', style: AppText.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  personal
                      ? 'Based on the activity, your pace, weight, height, age and sex.'
                      : 'Add your weight, height, year of birth and sex in your profile for a personal estimate.',
                  style: AppText.muted,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('activity-kcal'),
                  controller: _kcal,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Your own number (optional)',
                    hintText: 'e.g. from your watch',
                  ),
                ),
              ],
            ),
          ),
          label('NOTES'),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'How did it go?'),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: _saving ? 'Saving...' : 'Save activity',
            icon: Icons.check_rounded,
            onPressed: _saving || _duration.inMinutes <= 0 ? null : () => _save(estimate),
          ),
        ],
      ),
    );
  }
}

/// Seconds as "m:ss".
String _formatPace(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
