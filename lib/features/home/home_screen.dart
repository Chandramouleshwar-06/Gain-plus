import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../models/workout_plan.dart';
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
    return Consumer2<PlansProvider, WorkoutProvider>(
      builder: (context, plansProvider, workoutProvider, child) {
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

        if (workoutProvider.isWorkoutActive) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout in progress',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  workoutProvider.activePlanName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Resume Workout',
                  onPressed: () => MainScreen.of(context)?.setIndex(1),
                  isLarge: true,
                ),
              ],
            ),
          );
        }

        final todayPlan = plansProvider.planForDate(DateTime.now());

        if (todayPlan == null) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Workout",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nothing scheduled today',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take a rest day, or pick a plan to train anyway.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Choose a Workout',
                  onPressed: () => _showPlanPicker(context, plans),
                  isLarge: true,
                ),
              ],
            ),
          );
        }

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
                text: 'Start Workout',
                onPressed: () => _startPlan(context, todayPlan),
                isLarge: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startPlan(BuildContext context, WorkoutPlan plan) async {
    final exerciseProvider = context.read<ExerciseProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final mainScreen = MainScreen.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (exerciseProvider.exercises.isEmpty) {
      await exerciseProvider.loadExercises();
    }

    // Skip any exercise IDs that no longer exist instead of crashing.
    final workoutExercises = <WorkoutExercise>[];
    for (final item in plan.items) {
      final exercise = exerciseProvider.exercises.where((e) => e.id == item.exerciseId).firstOrNull;
      if (exercise == null) continue;
      workoutExercises.add(WorkoutExercise(
        exerciseId: item.exerciseId,
        name: exercise.name,
        sets: [for (var i = 0; i < item.targetSets; i++) WorkoutSet()],
      ));
    }

    if (workoutExercises.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('${plan.name} has no exercises yet. Add some in Plans.')),
      );
      return;
    }

    workoutProvider.startWorkout(plan.id, plan.name, workoutExercises);
    mainScreen?.setIndex(1); // Workout tab
  }

  void _showPlanPicker(BuildContext context, List<WorkoutPlan> plans) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Choose a Workout', style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  itemBuilder: (_, index) {
                    final plan = plans[index];
                    return ListTile(
                      leading: const Icon(Icons.fitness_center, color: AppTheme.accentBlue),
                      title: Text(plan.name, style: const TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(
                        '${plan.exerciseIds.length} exercises',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _startPlan(context, plan);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
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
                            workout.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${workout.startedAt.day}/${workout.startedAt.month}/${workout.startedAt.year} • '
                            '${workout.durationMinutes} min • ${workout.totalVolume.toStringAsFixed(0)} kg',
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
