import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../profile/profile_provider.dart';
import '../settings/settings_provider.dart';
import '../progress/achievement_tracker.dart';
import '../progress/achievements_view.dart';
import '../progress/progress_provider.dart';
import 'overload.dart';
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
            // Remove this route specifically, not whatever is on top (e.g. a
            // celebration dialog shown right after finishing).
            final route = ModalRoute.of(context);
            if (context.mounted && route != null && route.isActive) Navigator.of(context).removeRoute(route);
          });
          return const Scaffold();
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(provider: provider),
                const _RestTimerCard(),
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
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final progress = context.read<ProgressProvider>();
    final profile = context.read<ProfileProvider>();
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
    final achieved = await profile.markAchievedGoals(progress.prKgByExerciseId);
    if (achieved.isNotEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Goal reached! Check your profile.')));
    }
    final unlocked = await AchievementTracker.instance.checkNew(achievementStats(progress, profile));
    final overlayContext = rootNavigator.overlay?.context;
    if (unlocked.isNotEmpty && overlayContext != null && overlayContext.mounted) {
      await showAchievementsUnlocked(overlayContext, unlocked);
    }
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
    final previous = provider.previousSets[exercise.exerciseId] ?? const <SetEntry>[];
    final suggestion = suggestNext(previous, targetReps: exercise.targetReps, increment: exercise.increment);
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
          if (exercise.targetReps != null) ...[
            const SizedBox(height: 2),
            Text('Target: ${exercise.sets.length} × ${exercise.targetReps}', style: AppText.muted),
          ],
          if (suggestion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: suggestion.increase ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(suggestion.increase ? Icons.trending_up_rounded : Icons.repeat_rounded,
                      color: const Color(0xFFD8F56A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion.message,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD8F56A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _SetGridRow(
            children: [
              Text('SET', style: AppText.eyebrow, textAlign: TextAlign.center),
              Text('PREVIOUS', style: AppText.eyebrow, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
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
                previous: i < previous.length ? previous[i] : null,
                suggestedWeight: suggestion?.weight,
                onChanged: (weight, reps) => provider.updateSet(exercise, i, weight, reps),
                onToggle: () => provider.toggleSetComplete(exercise, i,
                    restSeconds: context.read<SettingsProvider>().restAfterSet),
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
        SizedBox(width: 30, child: children[0]),
        const SizedBox(width: 6),
        Expanded(flex: 6, child: children[1]),
        const SizedBox(width: 6),
        Expanded(flex: 5, child: children[2]),
        const SizedBox(width: 6),
        Expanded(flex: 5, child: children[3]),
        const SizedBox(width: 6),
        SizedBox(width: 46, child: children[4]),
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

  /// The same set from last time, if there was one.
  final SetEntry? previous;

  /// Weight suggested for today, shown as the placeholder.
  final double? suggestedWeight;

  const _SetRow({
    super.key,
    required this.set,
    required this.setNumber,
    required this.onChanged,
    required this.onToggle,
    this.previous,
    this.suggestedWeight,
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

  // Accept "2,5" as well as "2.5" for locales with a decimal comma.
  double get _typedWeight => double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
  int get _typedReps => int.tryParse(_repsController.text) ?? 0;

  void _notifyChanged() => widget.onChanged(_typedWeight, _typedReps);

  /// Ticking an empty set fills in the placeholder values first, so it
  /// doesn't save as 0 × 0.
  void _toggle() {
    if (!widget.set.completed && _typedWeight == 0 && _typedReps == 0) _usePrevious();
    widget.onToggle();
  }

  /// Copies last time's weight and reps into this set.
  void _usePrevious() {
    final previous = widget.previous;
    if (previous == null) return;
    _weightController.text = formatWeight(widget.suggestedWeight ?? previous.weight);
    _repsController.text = '${previous.reps}';
    _notifyChanged();
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
          Semantics(
            button: widget.previous != null,
            label: widget.previous == null ? 'No previous set' : 'Use last time\'s values',
            child: InkWell(
              onTap: widget.previous == null ? null : _usePrevious,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  widget.previous == null
                      ? '—'
                      : '${formatWeight(widget.previous!.weight)}×${widget.previous!.reps}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          _NumberField(
            controller: _weightController,
            hint: widget.suggestedWeight != null
                ? formatWeight(widget.suggestedWeight!)
                : widget.previous != null
                    ? formatWeight(widget.previous!.weight)
                    : 'kg',
            label: 'Set ${widget.setNumber} weight in kg',
            decimal: true,
            onChanged: _notifyChanged,
          ),
          _NumberField(
            controller: _repsController,
            hint: widget.previous != null ? '${widget.previous!.reps}' : 'reps',
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
                onTap: _toggle,
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

/// Countdown between sets. Appears when a set is ticked off, buzzes when
/// rest is over, then shows "GO" for a moment.
class _RestTimerCard extends StatefulWidget {
  const _RestTimerCard();

  @override
  State<_RestTimerCard> createState() => _RestTimerCardState();
}

class _RestTimerCardState extends State<_RestTimerCard> {
  Timer? _ticker;
  DateTime? _goUntil;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final provider = context.read<WorkoutProvider>();
    final endsAt = provider.restEndsAt;
    if (endsAt != null && !endsAt.isAfter(DateTime.now())) {
      _goUntil = DateTime.now().add(const Duration(seconds: 3));
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);
      provider.endRest();
    }
    if (provider.restEndsAt != null || _goUntil != null) setState(() {});
    if (_goUntil != null && _goUntil!.isBefore(DateTime.now())) _goUntil = null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final endsAt = provider.restEndsAt;
    final showGo = endsAt == null && _goUntil != null && _goUntil!.isAfter(DateTime.now());

    Widget child = const SizedBox(width: double.infinity);
    if (endsAt != null) {
      final remaining = endsAt.difference(DateTime.now());
      final seconds = remaining.inMilliseconds <= 0 ? 0 : (remaining.inMilliseconds / 1000).ceil();
      final fraction = provider.restTotalSeconds == 0 ? 0.0 : seconds / provider.restTotalSeconds;
      child = _card(
        color: AppColors.surface,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text('REST', style: AppText.eyebrow.copyWith(color: AppColors.lime)),
                      const SizedBox(width: 10),
                      Text(
                        formatElapsed(Duration(seconds: seconds)),
                        style: AppText.display(34).copyWith(fontFeatures: AppText.tabular),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _restButton('−15', () => provider.adjustRest(-15), label: 'Remove 15 seconds'),
              const SizedBox(width: 6),
              _restButton('+15', () => provider.adjustRest(15), label: 'Add 15 seconds'),
              const SizedBox(width: 6),
              _restButton('Skip', provider.endRest, primary: true),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(value: fraction, height: 6),
        ],
      );
    } else if (showGo) {
      child = _card(
        color: AppColors.lime,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.onLime, size: 28),
              const SizedBox(width: 8),
              Text('GO! NEXT SET', style: AppText.display(28, color: AppColors.onLime)),
            ],
          ),
        ],
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
    );
  }

  Widget _card({required Color color, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _restButton(String text, VoidCallback onPressed, {bool primary = false, String? label}) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: label != null,
      child: SizedBox(
        height: 44,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: primary ? AppColors.text : AppColors.surfaceHigh,
            foregroundColor: primary ? AppColors.onLime : AppColors.text,
            minimumSize: const Size(50, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
