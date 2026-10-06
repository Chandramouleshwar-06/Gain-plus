import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../exercise/exercise_provider.dart';
import 'plans_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().loadPlans();
      context.read<ExerciseProvider>().loadExercises();
    });
  }

  void _sharePlan(BuildContext context, int planId) {
    final plansProvider = context.read<PlansProvider>();
    final exerciseProvider = context.read<ExerciseProvider>();
    
    final plan = plansProvider.plans.firstWhere((p) => p.id == planId);
    final planExercises = exerciseProvider.exercises
        .where((e) => plan.exerciseIds.contains(e.id))
        .toList();

    String shareText = 'Check out my workout plan: ${plan.name}\n\n';
    if (planExercises.isEmpty) {
      shareText += 'No exercises added yet.';
    } else {
      for (var i = 0; i < planExercises.length; i++) {
        shareText += '${i + 1}. ${planExercises[i].name} (${planExercises[i].muscleGroup})\n';
      }
    }
    
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Plans',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    onPressed: () => _showCreatePlanDialog(context),
                    icon: const Icon(Icons.add, color: AppTheme.accentBlue, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer2<PlansProvider, ExerciseProvider>(
                builder: (context, plansProvider, exerciseProvider, child) {
                  if (plansProvider.plans.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No workout plans yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create one to start tracking',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plansProvider.plans.length,
                    itemBuilder: (context, index) {
                      final plan = plansProvider.plans[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          onTap: () => _showPlanDetails(context, plan.id!),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${plan.exerciseIds.length} exercises',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 20, color: AppTheme.accentBlue),
                                    onPressed: () => _sharePlan(context, plan.id!),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
    );
  }

  void _showPlanDetails(BuildContext context, int planId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.primaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Consumer2<PlansProvider, ExerciseProvider>(
              builder: (context, plansProvider, exerciseProvider, child) {
                final plan = plansProvider.plans.firstWhere((p) => p.id == planId);
                final planExercises = exerciseProvider.exercises
                    .where((e) => plan.exerciseIds.contains(e.id))
                    .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddExerciseToPlanDialog(context, planId),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Exercise'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: planExercises.isEmpty
                          ? Center(
                              child: Text(
                                'No exercises in this plan yet',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: planExercises.length,
                              itemBuilder: (context, index) {
                                final exercise = planExercises[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AppCard(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.fitness_center, color: AppTheme.accentBlue),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                exercise.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                exercise.muscleGroup,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                          onPressed: () {
                                            plansProvider.removeExerciseFromPlan(planId, exercise.id!);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddExerciseToPlanDialog(BuildContext context, int planId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Consumer2<PlansProvider, ExerciseProvider>(
              builder: (context, plansProvider, exerciseProvider, child) {
                final plan = plansProvider.plans.firstWhere((p) => p.id == planId);
                final availableExercises = exerciseProvider.exercises
                    .where((e) => !plan.exerciseIds.contains(e.id))
                    .toList();

                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Add Exercise to Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: availableExercises.isEmpty
                          ? const Center(child: Text('All exercises are already in this plan'))
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: availableExercises.length,
                              itemBuilder: (context, index) {
                                final exercise = availableExercises[index];
                                return ListTile(
                                  title: Text(exercise.name, style: const TextStyle(color: AppTheme.textPrimary)),
                                  subtitle: Text(exercise.muscleGroup, style: const TextStyle(color: AppTheme.textSecondary)),
                                  trailing: const Icon(Icons.add, color: AppTheme.accentBlue),
                                  onTap: () {
                                    plansProvider.addExerciseToPlan(planId, exercise.id!);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameController = TextEditingController();
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
                'Create Workout Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Plan name (e.g., Push Day, Leg Day)',
                  filled: true,
                  fillColor: AppTheme.primaryBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Create Plan',
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    context.read<PlansProvider>().createPlan(nameController.text);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
