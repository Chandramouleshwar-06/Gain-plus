import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/equipment.dart';
import '../../models/exercise.dart';
import '../profile/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../plans/plans_provider.dart';
import 'exercise_provider.dart';

/// The Exercises section of the Train tab: the exercise library.
class ExercisesView extends StatefulWidget {
  const ExercisesView({super.key});

  @override
  State<ExercisesView> createState() => _ExercisesViewState();
}

class _ExercisesViewState extends State<ExercisesView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _muscleGroup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final q = _query.toLowerCase();
    final filtered = provider.exercises.where((e) {
      final matchesQuery =
          q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.muscleGroup.toLowerCase().contains(q);
      final matchesGroup =
          _muscleGroup == null ||
          e.muscleGroup.split('/').map((g) => g.trim()).contains(_muscleGroup);
      return matchesQuery && matchesGroup;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Add exercise',
                onPressed: () => _showAddExerciseSheet(context, _query),
                style: IconButton.styleFrom(fixedSize: const Size(50, 50)),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final group in [null, ...provider.muscleGroups])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(group ?? 'All'),
                    selected: _muscleGroup == group,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: _muscleGroup == group
                          ? AppColors.onLime
                          : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _muscleGroup = group),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: _query.isEmpty
                      ? 'Nothing in this group yet.'
                      : 'Nothing matches "$_query".',
                  action: _query.isEmpty
                      ? null
                      : PrimaryButton(
                          text: 'Add "$_query"',
                          onPressed: () =>
                              _showAddExerciseSheet(context, _query),
                        ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _ExerciseTile(exercise: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _showExerciseDetails(context, exercise),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.lime,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: AppText.strong),
                const SizedBox(height: 2),
                Text(exercise.muscleGroup, style: AppText.muted),
                if (missingEquipment(
                      exercise.equipment,
                      context.watch<ProfileProvider>().availableEquipment,
                    )
                    case final missing when missing.isNotEmpty)
                  Text(
                    'Needs ${missing.map(Equipment.shortLabel).join(', ')}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
              ],
            ),
          ),
          if (exercise.isCustom) const InfoChip('Custom'),
        ],
      ),
    );
  }
}

void _showAddExerciseSheet(BuildContext context, String initialName) {
  final nameController = TextEditingController(text: initialName);
  final muscleController = TextEditingController();
  final notesController = TextEditingController();
  final equipment = <String>{};

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('NEW EXERCISE', style: AppText.display(26)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Exercise name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: muscleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Muscle group',
                hintText: 'e.g. Chest, Back/Biceps',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            const Text('EQUIPMENT NEEDED', style: AppText.eyebrow),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in Equipment.all)
                  FilterChip(
                    label: Text(Equipment.labels[code]!),
                    selected: equipment.contains(code),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: equipment.contains(code)
                          ? AppColors.onLime
                          : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (on) => setSheetState(
                      () => on ? equipment.add(code) : equipment.remove(code),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Leave all off for a bodyweight exercise.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Save exercise',
              onPressed: () async {
                final name = nameController.text.trim();
                final muscleGroup = muscleController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                if (name.isEmpty || muscleGroup.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Add a name and a muscle group.'),
                    ),
                  );
                  return;
                }

                final navigator = Navigator.of(sheetContext);
                final added = await context
                    .read<ExerciseProvider>()
                    .addExercise(
                      name: name,
                      muscleGroup: muscleGroup,
                      notes: notesController.text.trim(),
                      equipment: Equipment.all
                          .where(equipment.contains)
                          .toList(),
                    );
                if (!added) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('"$name" already exists.')),
                  );
                  return;
                }
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text('Added $name.')));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showExerciseDetails(BuildContext context, Exercise exercise) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name.toUpperCase(), style: AppText.display(28)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                InfoChip(exercise.muscleGroup),
                if (exercise.isCustom) const InfoChip('Custom'),
              ],
            ),
            if (exercise.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('NOTES', style: AppText.eyebrow),
              const SizedBox(height: 4),
              Text(exercise.notes, style: AppText.body),
            ],
            if (exercise.isCustom) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete exercise'),
                onPressed: () async {
                  final navigator = Navigator.of(sheetContext);
                  final exercises = context.read<ExerciseProvider>();
                  final plans = context.read<PlansProvider>();
                  final ok = await confirmDialog(
                    sheetContext,
                    title: 'Delete exercise?',
                    message:
                        '${exercise.name} will be removed from your plans. Past workouts keep it.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok) return;
                  await exercises.deleteExercise(exercise.id);
                  await plans.loadPlans();
                  navigator.pop();
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
