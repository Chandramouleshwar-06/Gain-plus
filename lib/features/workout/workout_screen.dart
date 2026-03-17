import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
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
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          provider.activePlanName,
                          style: Theme.of(context).textTheme.headlineMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${provider.elapsedTime} min',
                        style: Theme.of(context).textTheme.bodySmall,
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
                    onPressed: () {
                      provider.finishWorkout();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Workout saved! Great job!')),
                      );
                    },
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

  Widget _buildExerciseCard(BuildContext context, WorkoutExercise exercise, WorkoutProvider provider) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
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
                      '${setIndex + 1}',
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
                            decoration: const InputDecoration(
                              hintText: 'kg',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            onChanged: (value) {
                              final weight = double.tryParse(value) ?? 0;
                              provider.updateSet(exercise, setIndex, weight, set.reps);
                            },
                          ),
                        ),
                        const Text('×', style: TextStyle(color: AppTheme.textSecondary)),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'reps',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            onChanged: (value) {
                              final reps = int.tryParse(value) ?? 0;
                              provider.updateSet(exercise, setIndex, set.weight, reps);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: set.completed,
                    onChanged: (value) {
                      provider.toggleSetComplete(exercise, setIndex);
                    },
                    activeColor: AppTheme.success,
                  ),
                ],
              ),
            );
          }).toList(),
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
