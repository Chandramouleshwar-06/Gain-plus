import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/exercise.dart';
import '../../models/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../exercise/exercise_provider.dart';
import '../workout/workout_launcher.dart';
import 'plans_provider.dart';

/// The Plans section of the Train tab.
class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>().plans;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
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
                                      ],
                                    ),
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

/// Searchable list of exercises, minus [excludeIds].
class ExercisePicker extends StatefulWidget {
  final Set<String> excludeIds;
  final ScrollController? scrollController;
  final ValueChanged<Exercise> onPick;

  const ExercisePicker({super.key, required this.onPick, this.excludeIds = const {}, this.scrollController});

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final available = context
        .watch<ExerciseProvider>()
        .exercises
        .where((e) => !widget.excludeIds.contains(e.id))
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q) || e.muscleGroup.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search exercises',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: available.isEmpty
              ? const Center(child: Text('No matching exercises', style: AppText.muted))
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final exercise = available[index];
                    return ListTile(
                      title: Text(exercise.name, style: AppText.strong),
                      subtitle: Text(exercise.muscleGroup, style: AppText.muted),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.lime),
                      onTap: () => widget.onPick(exercise),
                    );
                  },
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
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(action)),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
