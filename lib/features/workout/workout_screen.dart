import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../progress/progress_provider.dart';
import 'workout_launcher.dart';
import 'workout_provider.dart';

/// The workout in progress, shown full-screen over the tabs.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        if (!provider.isWorkoutActive) {
          // Finished or discarded: close this screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold();
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(provider: provider),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: provider.exercises.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _ExerciseCard(exercise: provider.exercises[index], provider: provider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final WorkoutProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: 'Minimize',
            style: IconButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.text),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  provider.activePlanName.toUpperCase(),
                  style: AppText.eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _ElapsedTimer(startTime: provider.startTime!),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () => _confirmFinish(context, provider),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
              child: Text('FINISH', style: AppText.display(18, color: AppColors.onLime, weight: FontWeight.w700)),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: AppColors.surfaceHigh,
            onSelected: (value) {
              if (value == 'discard') _confirmDiscard(context, provider);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'discard',
                child: Text('Discard workout', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFinish(BuildContext context, WorkoutProvider provider) async {
    final completed = provider.completedSetCount;

    if (completed == 0) {
      final discard = await confirmDialog(
        context,
        title: 'No completed sets',
        message: 'Tick off at least one set to save this workout, or discard it.',
        cancelLabel: 'Keep going',
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (discard) await provider.discardWorkout();
      return;
    }

    final confirmed = await confirmDialog(
      context,
      title: 'Finish workout?',
      message: 'Save $completed completed ${completed == 1 ? 'set' : 'sets'}. '
          "Sets that aren't ticked off won't be saved.",
      confirmLabel: 'Finish',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final progress = context.read<ProgressProvider>();
    try {
      await provider.finishWorkout();
    } catch (e) {
      debugPrint('Failed to save workout: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the workout. Please try again.")),
      );
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Workout saved. Great job!')));
    // Refresh streak, recent workouts and PRs on Home and Progress.
    await progress.loadData();
  }

  Future<void> _confirmDiscard(BuildContext context, WorkoutProvider provider) async {
    final discard = await confirmDialog(
      context,
      title: 'Discard workout?',
      message: 'Everything you logged in this workout will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (discard) await provider.discardWorkout();
  }
}

class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise exercise;
  final WorkoutProvider provider;

  const _ExerciseCard({required this.exercise, required this.provider});

  @override
  Widget build(BuildContext context) {
    final done = exercise.sets.where((s) => s.completed).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(exercise.name.toUpperCase(), style: AppText.display(24, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$done / ${exercise.sets.length}', style: AppText.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SetGridRow(
            children: [
              Text('SET', style: AppText.eyebrow, textAlign: TextAlign.center),
              Text('KG', style: AppText.eyebrow),
              Text('REPS', style: AppText.eyebrow),
              Text('DONE', style: AppText.eyebrow, textAlign: TextAlign.center),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < exercise.sets.length; i++)
            Dismissible(
              key: ObjectKey(exercise.sets[i]),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
              onDismissed: (_) => provider.removeSet(exercise, i),
              child: _SetRow(
                key: ObjectKey(exercise.sets[i]),
                set: exercise.sets[i],
                setNumber: i + 1,
                onChanged: (weight, reps) => provider.updateSet(exercise, i, weight, reps),
                onToggle: () => provider.toggleSetComplete(exercise, i),
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => provider.addSet(exercise),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add set'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lime,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: Color(0xFF3A3A3F)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Column layout shared by the header and every set row.
class _SetGridRow extends StatelessWidget {
  final List<Widget> children;
  const _SetGridRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 36, child: children[0]),
        const SizedBox(width: 8),
        Expanded(child: children[1]),
        const SizedBox(width: 8),
        Expanded(child: children[2]),
        const SizedBox(width: 8),
        SizedBox(width: 48, child: children[3]),
      ],
    );
  }
}

/// Shows the time since [startTime], updating every second.
class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;

  const _ElapsedTimer({required this.startTime});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatElapsed(DateTime.now().difference(widget.startTime)),
      style: AppText.display(30).copyWith(fontFeatures: AppText.tabular),
    );
  }
}

/// One set's weight/reps inputs. Owns its text controllers so typed values
/// survive the list scrolling the row off-screen and back.
class _SetRow extends StatefulWidget {
  final WorkoutSet set;
  final int setNumber;
  final void Function(double weight, int reps) onChanged;
  final VoidCallback onToggle;

  const _SetRow({
    super.key,
    required this.set,
    required this.setNumber,
    required this.onChanged,
    required this.onToggle,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    final weight = widget.set.weight;
    _weightController = TextEditingController(text: weight == 0 ? '' : formatWeight(weight));
    _repsController = TextEditingController(
      text: widget.set.reps == 0 ? '' : widget.set.reps.toString(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    // Accept "2,5" as well as "2.5" for locales with a decimal comma.
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    widget.onChanged(weight, reps);
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.set.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: completed ? AppColors.lime.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _SetGridRow(
        children: [
          Text('${widget.setNumber}', textAlign: TextAlign.center, style: AppText.display(20, weight: FontWeight.w700)),
          _NumberField(
            controller: _weightController,
            hint: 'kg',
            label: 'Set ${widget.setNumber} weight in kg',
            decimal: true,
            onChanged: _notifyChanged,
          ),
          _NumberField(
            controller: _repsController,
            hint: 'reps',
            label: 'Set ${widget.setNumber} reps',
            onChanged: _notifyChanged,
          ),
          Semantics(
            label: 'Set ${widget.setNumber} done',
            checked: completed,
            child: Material(
              color: completed ? AppColors.lime : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: completed ? BorderSide.none : const BorderSide(color: Color(0xFF3A3A3F), width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onToggle,
                child: SizedBox(
                  height: 42,
                  child: completed
                      ? const Icon(Icons.check_rounded, color: AppColors.onLime, size: 24)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final bool decimal;
  final VoidCallback onChanged;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.label,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          fillColor: const Color(0xFF0F0F11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2E2E32)),
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
