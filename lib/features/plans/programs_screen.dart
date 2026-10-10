import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/programs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import 'plans_provider.dart';

/// Browse ready-made programs and add one to your plans.
class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('PROGRAMS', style: AppText.display(38)),
          const SizedBox(height: 6),
          const Text('Proven training plans. Add one and it becomes your plans, ready to edit.', style: AppText.muted),
          const SizedBox(height: 20),
          for (final program in programs) ...[
            AppCard(
              onTap: () => _showProgram(context, program),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(program.name.toUpperCase(), style: AppText.display(26))),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(program.summary, style: AppText.muted),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(program.level),
                      InfoChip('${program.defaultWeekdays.length} days / week'),
                      InfoChip(program.days.length == 1 ? '1 workout' : '${program.days.length} workouts'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  void _showProgram(BuildContext context, Program program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProgramSheet(program: program),
    );
  }
}

class _ProgramSheet extends StatefulWidget {
  final Program program;
  const _ProgramSheet({required this.program});

  @override
  State<_ProgramSheet> createState() => _ProgramSheetState();
}

class _ProgramSheetState extends State<_ProgramSheet> {
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  late Set<int> _weekdays = widget.program.defaultWeekdays.toSet();
  bool _schedule = true;
  int _weeks = 4;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text(program.name.toUpperCase(), style: AppText.display(32)),
                const SizedBox(height: 6),
                Text(program.summary, style: AppText.muted),
                const SizedBox(height: 16),
                for (final day in program.days) ...[
                  AppCard(
                    color: AppColors.surfaceHigh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.name.toUpperCase(), style: AppText.display(20, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final e in day.exercises)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.name, style: AppText.body)),
                                Text(e.reps == null ? '${e.sets} sets' : '${e.sets} × ${e.reps}', style: AppText.muted),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _schedule,
                  onChanged: (v) => setState(() => _schedule = v),
                  title: const Text('Add to my schedule', style: AppText.strong),
                  subtitle: const Text('With a reminder on each training day', style: AppText.muted),
                ),
                if (_schedule) ...[
                  const SizedBox(height: 8),
                  const Text('TRAINING DAYS', style: AppText.eyebrow),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Semantics(
                              label: _dayNames[d - 1],
                              selected: _weekdays.contains(d),
                              button: true,
                              child: Material(
                                color: _weekdays.contains(d) ? AppColors.lime : AppColors.surfaceHigh,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() {
                                    _weekdays = {..._weekdays};
                                    _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d);
                                  }),
                                  child: SizedBox(
                                    height: 44,
                                    child: Center(
                                      child: Text(
                                        _dayLetters[d - 1],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _weekdays.contains(d) ? AppColors.onLime : AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('FOR', style: AppText.eyebrow),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final w in [4, 8, 12])
                        ChoiceChip(
                          label: Text('$w weeks'),
                          selected: _weeks == w,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: _weeks == w ? AppColors.onLime : AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _weeks = w),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_rounded),
                    title: const Text('Reminder time', style: AppText.strong),
                    trailing: Text(_time.format(context),
                        style: AppText.display(20, weight: FontWeight.w700, color: AppColors.lime)),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: PrimaryButton(
                text: 'Add program',
                isLarge: true,
                onPressed: _saving || (_schedule && _weekdays.isEmpty) ? null : _install,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _install() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheduled = await context.read<PlansProvider>().installProgram(
          widget.program,
          weekdays: _schedule ? (_weekdays.toList()..sort()) : const [],
          weeks: _weeks,
          time: _time,
        );
    navigator.pop(); // sheet
    navigator.pop(); // programs screen
    messenger.showSnackBar(SnackBar(
      content: Text(scheduled == 0
          ? 'Added ${widget.program.name} to your plans.'
          : 'Added ${widget.program.name} and scheduled $scheduled sessions.'),
    ));
  }
}
