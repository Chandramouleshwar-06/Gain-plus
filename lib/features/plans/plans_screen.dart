import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/exercise.dart';
import '../../models/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../../data/equipment.dart';
import '../exercise/exercise_provider.dart';
import '../profile/profile_provider.dart';
import '../workout/workout_launcher.dart';
import 'plans_provider.dart';
import '../../data/program_repository.dart';
import 'program_editor_screen.dart';
import 'programs_provider.dart';
import 'programs_screen.dart';

/// The Plans section of the Train tab.
class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>().plans;
    final programs = context.watch<ProgramsProvider>().programs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const SectionHeader(title: 'Programs'),
        for (final program in programs) ...[
          _ProgramCard(program: program),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: 'New program',
                icon: Icons.add_rounded,
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ProgramEditorScreen())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                text: 'Ready-made',
                icon: Icons.auto_awesome_rounded,
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgramsScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionHeader(title: 'Workouts'),
        PrimaryButton(
          text: 'New plan',
          icon: Icons.add_rounded,
          variant: ButtonVariant.secondary,
          onPressed: () => _createPlan(context),
        ),
        const SizedBox(height: 16),
        if (plans.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.list_alt_rounded,
              title: 'No plans yet',
              message: 'Create a plan and add the exercises you want to do.',
            ),
          )
        else
          for (final plan in plans) ...[
            _PlanCard(plan: plan),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _createPlan(BuildContext context) async {
    final name = await promptForText(context, title: 'New plan', hint: 'e.g. Push Day, Leg Day', action: 'Create');
    if (name == null || !context.mounted) return;
    final id = await context.read<PlansProvider>().createPlan(name);
    if (context.mounted) showPlanDetails(context, id);
  }
}

/// A custom program: workouts, training days and whether it's running.
class _ProgramCard extends StatelessWidget {
  final CustomProgram program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>();
    final names = program.planIds.map((id) => plans.planById(id)?.name).whereType<String>().toList();
    String? progress;
    if (program.startedOn != null) {
      final days = DateTime.now().difference(program.startedOn!).inDays;
      final week = (days ~/ 7 + 1).clamp(1, program.weeks);
      progress = 'Week $week of ${program.weeks}';
    }

    return AppCard(
      color: program.isActive ? AppColors.surfaceHigh : AppColors.surface,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ProgramEditorScreen(programId: program.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(program.name.toUpperCase(), style: AppText.display(24, weight: FontWeight.w700))),
              if (progress != null) InfoChip(progress, foreground: AppColors.lime),
            ],
          ),
          const SizedBox(height: 4),
          Text('${weekdaysLabel(program.weekdays)} · ${program.weeks} weeks', style: AppText.muted),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(names.join(' → '), style: AppText.muted, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (program.isActive) ...[
            const SizedBox(height: 10),
            ProgressBar(
              value: DateTime.now().difference(program.startedOn!).inDays / (program.weeks * 7),
              height: 6,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showPlanDetails(context, plan.id),
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name.toUpperCase(), style: AppText.display(24, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  plan.items.isEmpty
                      ? 'No exercises yet'
                      : '${plan.items.length} exercises · ~${estimateMinutes(plan)} min',
                  style: AppText.muted,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Start ${plan.name}',
            onPressed: plan.items.isEmpty ? null : () => startPlanWorkout(context, plan),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.onLime,
              disabledBackgroundColor: AppColors.surfaceHigh,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plan options',
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: AppColors.surfaceHigh,
            onSelected: (value) => _onMenu(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final provider = context.read<PlansProvider>();
    switch (value) {
      case 'share':
        _sharePlan(context);
      case 'rename':
        final name = await promptForText(context, title: 'Rename plan', initial: plan.name, action: 'Save');
        if (name != null) await provider.renamePlan(plan.id, name);
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: 'Delete plan?',
          message: '"${plan.name}" and its scheduled days will be removed. Past workouts are kept.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) await provider.deletePlan(plan.id);
    }
  }

  void _sharePlan(BuildContext context) {
    final exercises = context.read<ExerciseProvider>();
    final buffer = StringBuffer('Check out my workout plan: ${plan.name}\n\n');
    if (plan.items.isEmpty) buffer.write('No exercises added yet.');
    for (var i = 0; i < plan.items.length; i++) {
      final item = plan.items[i];
      final exercise = exercises.byId(item.exerciseId);
      if (exercise == null) continue;
      final reps = item.targetReps == null ? '' : ' × ${item.targetReps}';
      buffer.writeln('${i + 1}. ${exercise.name}: ${item.targetSets} sets$reps');
    }
    Share.share(buffer.toString());
  }
}

/// Bottom sheet listing a plan's exercises, with drag-to-reorder.
void showPlanDetails(BuildContext context, String planId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Consumer2<PlansProvider, ExerciseProvider>(
        builder: (context, plans, exercises, _) {
          final equipment = context.watch<ProfileProvider>().availableEquipment;
          final plan = plans.planById(planId);
          if (plan == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(plan.name.toUpperCase(), style: AppText.display(28)),
              ),
              Expanded(
                child: plan.items.isEmpty
                    ? const EmptyState(
                        icon: Icons.fitness_center_rounded,
                        title: 'No exercises',
                        message: 'Add the exercises for this plan.',
                      )
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        buildDefaultDragHandles: false,
                        itemCount: plan.items.length,
                        onReorderItem: (from, to) => plans.reorderPlan(planId, from, to),
                        itemBuilder: (context, index) {
                          final item = plan.items[index];
                          final exercise = exercises.byId(item.exerciseId);
                          return Padding(
                            key: ValueKey(item.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              color: AppColors.surfaceHigh,
                              onTap: () => _editTargets(context, planId, item, exercise?.name ?? 'Exercise'),
                              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(exercise?.name ?? 'Deleted exercise', style: AppText.strong),
                                        Text(
                                          '${item.targetSets} sets'
                                          '${item.targetReps == null ? '' : ' × ${item.targetReps}'}'
                                          '${exercise == null ? '' : ' · ${exercise.muscleGroup}'}',
                                          style: AppText.muted,
                                        ),
                                        if (exercise != null &&
                                            missingEquipment(exercise.equipment, equipment).isNotEmpty)
                                          Text(
                                            'Needs ${missingEquipment(exercise.equipment, equipment).map(Equipment.shortLabel).join(', ')}',
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (exercise != null)
                                    IconButton(
                                      tooltip: 'Swap exercise',
                                      icon: Icon(Icons.swap_horiz_rounded,
                                          color: missingEquipment(exercise.equipment, equipment).isEmpty
                                              ? AppColors.textMuted
                                              : AppColors.orange),
                                      onPressed: () => _swapInPlan(context, plan, item.id, exercise),
                                    ),
                                  IconButton(
                                    tooltip: 'Remove from plan',
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                                    onPressed: () => plans.removeExerciseFromPlan(planId, item.exerciseId),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: PrimaryButton(
                    text: 'Add exercise',
                    icon: Icons.add_rounded,
                    onPressed: () => _showAddExercise(context, plan),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void _showAddExercise(BuildContext context, WorkoutPlan plan) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => ExercisePicker(
        excludeIds: plan.exerciseIds.toSet(),
        scrollController: scrollController,
        onPick: (exercise) {
          context.read<PlansProvider>().addExerciseToPlan(plan.id, exercise.id);
          Navigator.pop(sheetContext);
        },
      ),
    ),
  );
}

/// Searchable list of exercises, minus [excludeIds]. Exercises needing
/// equipment you don't have are hidden unless you turn the filter off.
/// With [suggestFor], the best same-muscle swaps you can do come first.
class ExercisePicker extends StatefulWidget {
  final Set<String> excludeIds;
  final ScrollController? scrollController;
  final ValueChanged<Exercise> onPick;
  final Exercise? suggestFor;

  const ExercisePicker({
    super.key,
    required this.onPick,
    this.excludeIds = const {},
    this.scrollController,
    this.suggestFor,
  });

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  String _query = '';
  bool _onlyMine = true;

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>();
    final equipment = context.watch<ProfileProvider>().availableEquipment;
    final hasEverything = equipment.containsAll(Equipment.all);
    final q = _query.toLowerCase();

    final suggestions = widget.suggestFor == null || q.isNotEmpty
        ? <Exercise>[]
        : exercises
            .alternativesFor(widget.suggestFor!, equipment)
            .where((e) => !widget.excludeIds.contains(e.id))
            .take(5)
            .toList();
    final list = exercises.exercises
        .where((e) => !widget.excludeIds.contains(e.id))
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q) || e.muscleGroup.toLowerCase().contains(q))
        .where((e) => !_onlyMine || hasEquipmentFor(e.equipment, equipment))
        .toList();

    Widget tile(Exercise exercise) {
      final missing = missingEquipment(exercise.equipment, equipment);
      return ListTile(
        title: Text(exercise.name,
            style: AppText.strong.copyWith(color: missing.isEmpty ? AppColors.text : AppColors.textMuted)),
        subtitle: Text(
          missing.isEmpty
              ? exercise.muscleGroup
              : '${exercise.muscleGroup} · Needs ${missing.map(Equipment.shortLabel).join(', ')}',
          style: AppText.muted.copyWith(color: missing.isEmpty ? AppColors.textMuted : AppColors.orange),
        ),
        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.lime),
        onTap: () => widget.onPick(exercise),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search exercises',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (!hasEverything)
          SwitchListTile(
            dense: true,
            value: _onlyMine,
            onChanged: (v) => setState(() => _onlyMine = v),
            title: const Text('Only my equipment', style: AppText.strong),
          ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            children: [
              if (suggestions.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('SUGGESTED SWAPS', style: AppText.eyebrow),
                ),
                for (final e in suggestions) tile(e),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text('ALL EXERCISES', style: AppText.eyebrow),
                ),
              ],
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No matching exercises', style: AppText.muted)),
                ),
              for (final e in list) tile(e),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks for a single line of text. Returns the trimmed text, or null if
/// cancelled or empty.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String action,
  String? hint,
  String? initial,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: title,
      action: action,
      hint: hint,
      initial: initial,
      textCapitalization: TextCapitalization.words,
    ),
  );
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Edits how many sets and reps a plan exercise aims for.
Future<void> _editTargets(BuildContext context, String planId, PlanExercise item, String name) async {
  var sets = item.targetSets;
  int? reps = item.targetReps;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Widget stepper(String label, String value, VoidCallback? onMinus, VoidCallback? onPlus) => Expanded(
              child: Column(
                children: [
                  Text(label, style: AppText.eyebrow),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        tooltip: 'Less $label',
                        onPressed: onMinus,
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.text),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(width: 56, child: Text(value, textAlign: TextAlign.center, style: AppText.display(36))),
                      IconButton.filled(
                        tooltip: 'More $label',
                        onPressed: onPlus,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(name.toUpperCase(), style: AppText.display(24)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    stepper('SETS', '$sets', sets > 1 ? () => setSheetState(() => sets--) : null,
                        sets < 10 ? () => setSheetState(() => sets++) : null),
                    stepper(
                      'REPS',
                      reps == null ? '—' : '$reps',
                      reps == null ? null : () => setSheetState(() => reps = reps! <= 1 ? null : reps! - 1),
                      () => setSheetState(() => reps = (reps ?? 0) + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Leave reps at — for timed holds like planks.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                PrimaryButton(text: 'Save', onPressed: () => Navigator.pop(sheetContext, true)),
              ],
            ),
          ),
        );
      },
    ),
  );

  if (saved == true && context.mounted) {
    await context.read<PlansProvider>().updateTargets(planId, item.id, sets, reps);
  }
}

/// Swaps [current] in a plan for another exercise, suggesting ones that
/// work the same muscle with your equipment.
void _swapInPlan(BuildContext context, WorkoutPlan plan, String itemId, Exercise current) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SWAP ${current.name.toUpperCase()}', style: AppText.display(22)),
            ),
          ),
          Expanded(
            child: ExercisePicker(
              suggestFor: current,
              excludeIds: plan.exerciseIds.toSet(),
              scrollController: scrollController,
              onPick: (exercise) {
                context.read<PlansProvider>().replaceExerciseInPlan(plan.id, itemId, exercise.id);
                Navigator.pop(sheetContext);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
