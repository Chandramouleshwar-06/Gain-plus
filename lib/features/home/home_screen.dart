import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../progress/progress_provider.dart';
import '../plans/plans_provider.dart';
import '../workout/workout_provider.dart';
import '../exercise/exercise_provider.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().loadData();
      context.read<PlansProvider>().loadPlans();
      context.read<ExerciseProvider>().loadExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hey, User',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, size: 32, color: AppTheme.accentBlue),
                    onPressed: () {
                      MainScreen.of(context)?.setIndex(5); // Switch to Progress/Profile tab
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStreakCard(context),
              const SizedBox(height: 16),
              _buildTodayWorkoutCard(context),
              const SizedBox(height: 24),
              Text(
                'Recent Workouts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildRecentWorkouts(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        return AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: AppTheme.accentBlue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${provider.streak} Day Streak',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep it going!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayWorkoutCard(BuildContext context) {
    return Consumer3<PlansProvider, WorkoutProvider, ExerciseProvider>(
      builder: (context, plansProvider, workoutProvider, exerciseProvider, child) {
        final plans = plansProvider.plans;
        if (plans.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Workout Planned',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a workout plan to get started',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        final todayPlan = plans.first;
        
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Workout",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                todayPlan.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip('${todayPlan.exerciseIds.length} exercises'),
                  const SizedBox(width: 8),
                  _buildInfoChip('~45 min'),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: workoutProvider.isWorkoutActive ? 'Resume Workout' : 'Start Workout',
                onPressed: () {
                  if (!workoutProvider.isWorkoutActive) {
                    final workoutExercises = todayPlan.exerciseIds.map((id) {
                      final exercise = exerciseProvider.exercises.firstWhere((e) => e.id == id);
                      return WorkoutExercise(
                        exerciseId: id,
                        name: exercise.name,
                        sets: [WorkoutSet()],
                      );
                    }).toList();
                    
                    workoutProvider.startWorkout(todayPlan.name, workoutExercises);
                  }
                  
                  // Switch to Workout Tab (Index 1)
                  MainScreen.of(context)?.setIndex(1);
                },
                isLarge: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRecentWorkouts(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        if (provider.recentWorkouts.isEmpty) {
          return AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No workouts yet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        }

        return Column(
          children: provider.recentWorkouts.take(5).map((workout) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
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
                            '${workout.date.day}/${workout.date.month}/${workout.date.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${workout.duration} min • ${workout.totalVolume.toStringAsFixed(0)} kg',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
