import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/equipment.dart';
import '../../data/exercise_guides.dart';
import '../../data/muscles.dart';
import '../../models/exercise.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../plans/plans_provider.dart';
import '../progress/recovery_map.dart';
import 'exercise_provider.dart';

/// YouTube search for a form demo of [exerciseName].
Uri demoSearchUrl(String exerciseName) =>
    Uri.https('www.youtube.com', '/results', {'search_query': '$exerciseName proper form'});

/// How to do an exercise: muscles worked, setup, steps, cues, mistakes,
/// and a link to demo videos.
class ExerciseGuideScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseGuideScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final guide = exercise.isCustom ? null : guideFor(exercise.name);
    final (primary, secondary) = musclesFor(exercise);

    Widget section(String title, List<String> items, {IconData icon = Icons.circle, Color color = AppColors.lime}) =>
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.eyebrow),
              const SizedBox(height: 8),
              for (final (i, item) in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: icon == Icons.circle
                            ? Text('${i + 1}.', style: AppText.strong.copyWith(color: color))
                            : Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
                      ),
                      Expanded(child: Text(item, style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (exercise.isCustom)
            IconButton(
              tooltip: 'Delete exercise',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(exercise.name.toUpperCase(), style: AppText.display(32)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(exercise.muscleGroup),
              for (final e in exercise.equipment) InfoChip(Equipment.labels[e] ?? e),
              if (exercise.equipment.isEmpty) const InfoChip('Bodyweight'),
              if (exercise.isCustom) const InfoChip('Custom'),
            ],
          ),
          if (primary.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MuscleHighlight(primary: primary, secondary: secondary),
                  const SizedBox(height: 12),
                  Text('Works: ${primary.map((m) => m.label).join(', ')}', style: AppText.strong),
                  if (secondary.isNotEmpty)
                    Text('Also: ${secondary.map((m) => m.label).join(', ')}', style: AppText.muted),
                ],
              ),
            ),
          ],
          if (guide != null) ...[
            const SizedBox(height: 20),
            const Text('SETUP', style: AppText.eyebrow),
            const SizedBox(height: 8),
            Text(guide.setup, style: AppText.body),
            section('HOW TO DO IT', guide.steps),
            section('CUES', guide.cues, icon: Icons.check_rounded),
            section('AVOID', guide.mistakes, icon: Icons.close_rounded, color: AppColors.orange),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('No written guide for this exercise yet. Watch a demo below.', style: AppText.muted),
            ),
          if (exercise.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('NOTES', style: AppText.eyebrow),
            const SizedBox(height: 4),
            Text(exercise.notes, style: AppText.body),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Watch a demo',
            icon: Icons.play_circle_outline_rounded,
            variant: ButtonVariant.secondary,
            onPressed: () => _openDemo(context),
          ),
          const SizedBox(height: 8),
          const Text('Opens YouTube search results.', style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
        ],
      ),
    );
  }

  Future<void> _openDemo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(demoSearchUrl(exercise.name), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('not opened');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't open YouTube.")));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final exercises = context.read<ExerciseProvider>();
    final plans = context.read<PlansProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Delete exercise?',
      message: '${exercise.name} will be removed from your plans. Past workouts keep it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await exercises.deleteExercise(exercise.id);
    await plans.loadPlans();
    navigator.pop();
  }
}
