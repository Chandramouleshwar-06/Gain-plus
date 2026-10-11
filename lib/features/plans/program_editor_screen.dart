import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/program_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import 'plans_provider.dart';
import 'programs_provider.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Short "Mon · Wed · Fri" label for weekdays.
String weekdaysLabel(List<int> weekdays) =>
    weekdays.map((d) => _dayNames[d - 1].substring(0, 3)).join(' · ');

/// Create or edit a custom program.
class ProgramEditorScreen extends StatefulWidget {
  final String? programId;
  const ProgramEditorScreen({super.key, this.programId});

  @override
  State<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends State<ProgramEditorScreen> {
  late final TextEditingController _name;
  late List<String> _planIds;
  late Set<int> _weekdays;
  late int _weeks;
  late TimeOfDay _time;
  bool _busy = false;

  CustomProgram? get _existing => context.read<ProgramsProvider>().byId(widget.programId);

  @override
  void initState() {
    super.initState();
    final p = _existing;
    _name = TextEditingController(text: p?.name ?? '');
    _planIds = [...?p?.planIds];
    _weekdays = {...?p?.weekdays};
    if (_weekdays.isEmpty) _weekdays = {1, 3, 5};
    _weeks = p?.weeks ?? 8;
    final minutes = p?.reminderMinutes ?? 18 * 60;
    _time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _planIds.isNotEmpty && _weekdays.isNotEmpty;

  Future<String?> _save() async {
    if (!_valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a name, at least one workout and a training day.')),
      );
      return null;
    }
    return context.read<ProgramsProvider>().save(
          id: widget.programId,
          name: _name.text.trim(),
          weekdays: _weekdays.toList()..sort(),
          weeks: _weeks,
          planIds: _planIds,
          reminderMinutes: _time.hour * 60 + _time.minute,
        );
  }

  Future<void> _saveAndClose() async {
    if (_busy) return; // a double tap would save a new program twice
    setState(() => _busy = true);
    final id = await _save();
    if (!mounted) return;
    if (id != null) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final programs = context.read<ProgramsProvider>();
    final plans = context.read<PlansProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await confirmDialog(
      context,
      title: 'Start program?',
      message: 'Schedules ${_weekdays.length} days a week for $_weeks weeks from today, with reminders. '
          'Anything already scheduled on those days is replaced.',
      confirmLabel: 'Start',
    );
    if (!ok) return;

    setState(() => _busy = true);
    final id = await _save();
    if (id == null) {
      setState(() => _busy = false);
      return;
    }
    final count = await programs.start(programs.byId(id)!, reminderMinutes: _time.hour * 60 + _time.minute);
    await plans.loadPlans();
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Program started: $count sessions scheduled.')));
  }

  Future<void> _stop(CustomProgram program) async {
    final ok = await confirmDialog(
      context,
      title: 'Stop program?',
      message: 'Its remaining scheduled days are removed. You can start it again any time.',
      confirmLabel: 'Stop',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final plans = context.read<PlansProvider>();
    await context.read<ProgramsProvider>().stop(program);
    await plans.loadPlans();
  }

  Future<void> _delete(CustomProgram program) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete program?',
      message: 'The program and its remaining scheduled days are removed. Its workouts stay in your plans.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final plans = context.read<PlansProvider>();
    final navigator = Navigator.of(context);
    await context.read<ProgramsProvider>().delete(program);
    await plans.loadPlans();
    navigator.pop();
  }

  void _addWorkout() {
    final plans = context.read<PlansProvider>().plans;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('ADD A WORKOUT', style: AppText.display(24)),
              ),
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Create a plan first; programs are built from your plans.', style: AppText.muted),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final plan in plans)
                      ListTile(
                        leading: const Icon(Icons.fitness_center_rounded, color: AppColors.lime),
                        title: Text(plan.name, style: AppText.strong),
                        subtitle: Text('${plan.items.length} exercises', style: AppText.muted),
                        onTap: () {
                          setState(() => _planIds.add(plan.id));
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>();
    final program = context.watch<ProgramsProvider>().byId(widget.programId);
    final sessionsPerWeek = _weekdays.length;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (program != null)
            IconButton(
              tooltip: 'Delete program',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () => _delete(program),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(program == null ? 'NEW PROGRAM' : 'EDIT PROGRAM', style: AppText.display(34)),
          if (program?.isActive ?? false) ...[
            const SizedBox(height: 8),
            InfoChip('Running since ${program!.startedOn!.day}/${program.startedOn!.month}',
                foreground: AppColors.lime),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Program name', hintText: 'e.g. Summer Shred'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text('WORKOUTS, IN ORDER', style: AppText.eyebrow),
          const SizedBox(height: 4),
          const Text('They rotate through your training days: A, B, C, A, B, C...',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          if (_planIds.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _planIds.length,
              onReorderItem: (from, to) => setState(() => _planIds.insert(to, _planIds.removeAt(from))),
              itemBuilder: (context, i) {
                final plan = plans.planById(_planIds[i]);
                return Padding(
                  key: ValueKey('$i-${_planIds[i]}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
                          child: Text(String.fromCharCode(65 + i % 26),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.lime)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(plan?.name ?? 'Deleted plan', style: AppText.strong)),
                        IconButton(
                          tooltip: 'Remove from program',
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                          onPressed: () => setState(() => _planIds.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          PrimaryButton(
            text: 'Add workout',
            icon: Icons.add_rounded,
            variant: ButtonVariant.secondary,
            onPressed: _addWorkout,
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 6),
          Text('$sessionsPerWeek ${sessionsPerWeek == 1 ? 'session' : 'sessions'} a week', style: AppText.muted),
          const SizedBox(height: 24),
          const Text('LENGTH', style: AppText.eyebrow),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final w in [4, 6, 8, 12])
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          if (program?.isActive ?? false) ...[
            PrimaryButton(text: 'Save changes', onPressed: _busy ? null : _saveAndClose),
            const SizedBox(height: 8),
            PrimaryButton(text: 'Restart from today', variant: ButtonVariant.secondary, onPressed: _busy ? null : _start),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _stop(program!),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Stop program'),
            ),
          ] else ...[
            PrimaryButton(text: 'Start program', isLarge: true, onPressed: _busy || !_valid ? null : _start),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Save without starting',
              variant: ButtonVariant.secondary,
              onPressed: _busy ? null : _saveAndClose,
            ),
          ],
        ],
      ),
    );
  }
}
