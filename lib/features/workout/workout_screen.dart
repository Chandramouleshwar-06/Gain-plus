import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../progress/progress_provider.dart';
import 'workout_provider.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, provider, child) {
            if (!provider.isWorkoutActive) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active workout',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a workout from home',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.activePlanName,
                          style: Theme.of(context).textTheme.headlineMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ElapsedTimer(startTime: provider.startTime!),
                      IconButton(
                        tooltip: 'Discard workout',
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => _confirmDiscard(context, provider),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: provider.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = provider.exercises[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExerciseCard(context, exercise, provider),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: PrimaryButton(
                    text: 'Finish Workout',
                    onPressed: () => _confirmFinish(context, provider),
                    isLarge: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmFinish(BuildContext context, WorkoutProvider provider) async {
    final completed = provider.completedSetCount;

    if (completed == 0) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No completed sets'),
          content: const Text('Tick off at least one set to save this workout, or discard it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true) provider.discardWorkout();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(
          'Save $completed completed ${completed == 1 ? 'set' : 'sets'}. '
          "Sets that aren't ticked off won't be saved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

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
    messenger.showSnackBar(
      const SnackBar(content: Text('Workout saved! Great job!')),
    );
    // Refresh streak, recent workouts and PRs on Home and Progress.
    await progress.loadData();
  }

  Future<void> _confirmDiscard(BuildContext context, WorkoutProvider provider) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('Everything you logged in this workout will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) provider.discardWorkout();
  }

  Widget _buildExerciseCard(BuildContext context, WorkoutExercise exercise, WorkoutProvider provider) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${exercise.sets.length} sets',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...exercise.sets.asMap().entries.map((entry) {
            final setIndex = entry.key;
            final set = entry.value;
            return _SetRow(
              key: ObjectKey(set),
              set: set,
              setNumber: setIndex + 1,
              onChanged: (weight, reps) => provider.updateSet(exercise, setIndex, weight, reps),
              onToggle: () => provider.toggleSetComplete(exercise, setIndex),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => provider.addSet(exercise),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Set'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentBlue,
            ),
          ),
        ],
      ),
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
    final elapsed = DateTime.now().difference(widget.startTime);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
    _weightController = TextEditingController(
      text: weight == 0
          ? ''
          : (weight == weight.roundToDouble() ? weight.toInt().toString() : weight.toString()),
    );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.setNumber}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      hintText: 'kg',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ),
                const Text('×', style: TextStyle(color: AppTheme.textSecondary)),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      hintText: 'reps',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: widget.set.completed,
            onChanged: (_) => widget.onToggle(),
            activeColor: AppTheme.success,
          ),
        ],
      ),
    );
  }
}
