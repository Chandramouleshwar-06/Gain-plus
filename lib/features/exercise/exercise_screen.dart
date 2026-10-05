import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../models/exercise.dart';
import 'exercise_provider.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExerciseProvider>().loadExercises();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ExerciseProvider>(
                builder: (context, provider, child) {
                  final filteredExercises = provider.exercises
                      .where((e) => e.name.toLowerCase().contains(searchQuery))
                      .toList();

                  if (filteredExercises.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No exercises found matching "$searchQuery"',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Add "$searchQuery" as New Exercise',
                              onPressed: () => _showAddExerciseDialog(context, searchQuery),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = filteredExercises[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          onTap: () => _showExerciseDetails(context, exercise),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.fitness_center,
                                  color: AppTheme.accentBlue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      exercise.muscleGroup,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        onPressed: () => _showAddExerciseDialog(context, ''),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, String initialName) {
    final nameController = TextEditingController(text: initialName);
    final muscleController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Exercise',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              _buildField('Exercise Name', nameController),
              const SizedBox(height: 12),
              _buildField('Muscle Group (e.g., Chest, Legs)', muscleController),
              const SizedBox(height: 12),
              _buildField('Notes', notesController, maxLines: 3),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Save Exercise',
                onPressed: () async {
                  final name = nameController.text.trim();
                  final muscleGroup = muscleController.text.trim();
                  if (name.isEmpty || muscleGroup.isEmpty) return;

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final added = await context.read<ExerciseProvider>().addExercise(Exercise(
                    name: name,
                    muscleGroup: muscleGroup,
                    notes: notesController.text.trim(),
                  ));
                  if (!added) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('"$name" already exists.')),
                    );
                    return;
                  }
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Exercise added successfully!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(String hint, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.primaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: AppTheme.textPrimary),
    );
  }

  void _showExerciseDetails(BuildContext context, Exercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    exercise.muscleGroup,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (exercise.notes.isNotEmpty) ...[
                const Text(
                  'Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise.notes,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
