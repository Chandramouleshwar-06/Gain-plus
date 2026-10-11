import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../models/workout_plan.dart';
import '../../navigation/nav_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../nutrition/nutrition_provider.dart';
import '../nutrition/nutrition_screen.dart';
import '../plans/plans_provider.dart';
import '../plans/program_scheduler.dart';
import '../plans/programs_provider.dart';
import '../profile/goal_tile.dart';
import '../profile/profile_provider.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_provider.dart';
import '../workout/workout_launcher.dart';
import '../workout/workout_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.lime,
          onRefresh: () async {
            await Future.wait([
              context.read<ProgressProvider>().loadData(),
              context.read<PlansProvider>().loadPlans(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              _Header(now: now),
              const SizedBox(height: 20),
              _WeekStrip(now: now),
              const SizedBox(height: 20),
              const _MissedCard(),
              const _TodayCard(),
              const SizedBox(height: 16),
              _Stats(now: now),
              const SizedBox(height: 16),
              const _FoodCard(),
              const SizedBox(height: 24),
              const _Goals(),
              const _RecentWorkouts(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime now;
  const _Header({required this.now});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEE · d MMM').format(now).toUpperCase(), style: AppText.eyebrow),
              const SizedBox(height: 4),
              Text(_greeting(context.watch<ProfileProvider>().firstName), style: AppText.display(38), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => context.read<NavProvider>().goTo(AppTab.profile),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.lime, width: 2),
            fixedSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.person_rounded, color: AppColors.text),
        ),
      ],
    );
  }
}

/// Monday-to-Sunday strip marking days with a workout.
class _WeekStrip extends StatelessWidget {
  final DateTime now;
  const _WeekStrip({required this.now});

  @override
  Widget build(BuildContext context) {
    final days = context.watch<ProgressProvider>().workoutDays;
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(monday.year, monday.month, monday.day + i);
              final done = days.contains(day);
              final isToday = day == today;
              return Semantics(
                label: '${DateFormat('EEEE').format(day)}${done ? ', trained' : ''}',
                child: Column(
                  children: [
                    Text(
                      isToday ? 'TODAY' : letters[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.lime : (isToday ? Colors.transparent : AppColors.surfaceHigh),
                        border: isToday && !done ? Border.all(color: AppColors.lime, width: 2) : null,
                      ),
                      child: done ? const Icon(Icons.check_rounded, size: 18, color: AppColors.onLime) : null,
                    ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    final plans = context.watch<PlansProvider>();

    if (workout.isWorkoutActive) {
      return _LimeCard(
        eyebrow: 'IN PROGRESS',
        title: workout.activePlanName,
        chips: ['${workout.completedSetCount} sets done'],
        buttonLabel: 'Resume workout',
        onPressed: () => openActiveWorkout(context),
      );
    }

    if (plans.plans.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        radius: AppRadius.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GET STARTED', style: AppText.eyebrow),
            const SizedBox(height: 8),
            Text('CREATE YOUR FIRST PLAN', style: AppText.display(32)),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Go to Train',
              onPressed: () => context.read<NavProvider>().goTo(AppTab.train, section: TrainSection.plans),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final trainedToday =
        context.watch<ProgressProvider>().workoutDays.contains(DateTime(now.year, now.month, now.day));
    if (trainedToday) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        radius: AppRadius.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODAY', style: AppText.eyebrow),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('WORKOUT DONE', style: AppText.display(40))),
                const Icon(Icons.check_circle_rounded, color: AppColors.lime, size: 36),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Nice work. Rest up, or train again if you have more in the tank.', style: AppText.muted),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Train again',
              variant: ButtonVariant.secondary,
              onPressed: () => _showPlanPicker(context, plans.plans),
            ),
          ],
        ),
      );
    }

    final todayPlan = plans.planForDate(now);
    if (todayPlan != null) {
      return _LimeCard(
        eyebrow: "TODAY'S SESSION",
        title: todayPlan.name,
        chips: ['${todayPlan.items.length} exercises', '~${estimateMinutes(todayPlan)} min'],
        buttonLabel: 'Start workout',
        onPressed: () => startPlanWorkout(context, todayPlan),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppRadius.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: AppText.eyebrow),
          const SizedBox(height: 8),
          Text('REST DAY', style: AppText.display(44)),
          const SizedBox(height: 6),
          const Text('Nothing scheduled. Recover, or train anyway.', style: AppText.muted),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Choose a workout',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _showPlanPicker(context, plans.plans),
          ),
        ],
      ),
    );
  }

  void _showPlanPicker(BuildContext context, List<WorkoutPlan> plans) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('CHOOSE A WORKOUT', style: AppText.display(26)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plans.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return ListTile(
                        leading: const Icon(Icons.bolt_rounded, color: AppColors.lime),
                        title: const Text('Quick workout', style: AppText.strong),
                        subtitle: const Text('Start empty and add exercises as you go', style: AppText.muted),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          startEmptyWorkout(context);
                        },
                      );
                    }
                    final plan = plans[i - 1];
                    return ListTile(
                      leading: const Icon(Icons.fitness_center_rounded, color: AppColors.lime),
                      title: Text(plan.name, style: AppText.strong),
                      subtitle: Text('${plan.items.length} exercises · ~${estimateMinutes(plan)} min',
                          style: AppText.muted),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        startPlanWorkout(context, plan);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lime hero card from the design.
class _LimeCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<String> chips;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _LimeCard({
    required this.eyebrow,
    required this.title,
    required this.chips,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(AppRadius.hero)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: AppText.eyebrow.copyWith(color: AppColors.onLime)),
          const SizedBox(height: 10),
          Text(title.toUpperCase(), style: AppText.display(40, color: AppColors.onLime).copyWith(height: 0.95)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final c in chips) InfoChip.onLime(c)]),
          const SizedBox(height: 16),
          PrimaryButton(
            text: buttonLabel,
            icon: Icons.play_arrow_rounded,
            variant: ButtonVariant.inverse,
            isLarge: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final DateTime now;
  const _Stats({required this.now});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.orange,
            value: '${progress.streak}',
            label: 'day streak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.calendar_today_rounded,
            value: '${progress.workoutsThisWeek(now)}/${context.watch<ProfileProvider>().weeklyTarget}',
            label: 'this week',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.trending_up_rounded,
            value: context.watch<ProfileProvider>().units.volume(progress.totalVolume),
            label: 'lifted',
          ),
        ),
      ],
    );
  }
}

class _RecentWorkouts extends StatelessWidget {
  const _RecentWorkouts();

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<ProgressProvider>().recentWorkouts.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent',
          actionLabel: recent.isEmpty ? null : 'See all',
          onAction: () => context.read<NavProvider>().goTo(AppTab.progress),
        ),
        if (recent.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text('No workouts yet. Your first one will show up here.', style: AppText.muted),
            ),
          )
        else
          for (final w in recent) ...[
            WorkoutSummaryCard(workout: w),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// One past workout: name, date, duration and volume.
class WorkoutSummaryCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback? onTap;

  const WorkoutSummaryCard({super.key, required this.workout, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: AppColors.lime, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.name, style: AppText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('EEE d MMM').format(workout.startedAt)} · '
                  '${formatDuration(workout.durationSeconds)} · ${context.watch<ProfileProvider>().units.volume(workout.totalVolume)}',
                  style: AppText.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

String _greeting(String firstName) => firstName.isEmpty ? "LET'S GO" : "LET'S GO, ${firstName.toUpperCase()}";

/// Open goals (up to two), or a prompt to set one.
class _Goals extends StatelessWidget {
  const _Goals();

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<ProfileProvider>().goals;
    final open = [...goals.where((g) => g.achievedAt == null), ...goals.where((g) => g.achievedAt != null)];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Goals',
            actionLabel: goals.isEmpty ? 'Add' : 'See all',
            onAction: () => goals.isEmpty
                ? showAddGoalSheet(context)
                : context.read<NavProvider>().goTo(AppTab.profile),
          ),
          if (goals.isEmpty)
            AppCard(
              onTap: () => showAddGoalSheet(context),
              child: const Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppColors.lime),
                  SizedBox(width: 12),
                  Expanded(child: Text('Set a goal, like benching 100 kg.', style: AppText.muted)),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < open.length && i < 2; i++) ...[
                    if (i > 0) const Divider(),
                    GoalTile(goal: open[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Offers to catch up on a scheduled workout that was missed recently.
class _MissedCard extends StatelessWidget {
  const _MissedCard();

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>();
    final programs = context.watch<ProgramsProvider>();
    final progress = context.watch<ProgressProvider>();
    if (!progress.loaded) return const SizedBox.shrink();

    final missed = findMissed(
      schedules: plans.schedules.values.map((s) => (s.date, s.planId, s.programId)),
      trainedDays: progress.workoutDays,
      today: DateTime.now(),
    );
    final plan = missed == null ? null : plans.planById(missed.planId);
    if (missed == null || plan == null) return const SizedBox.shrink();

    final program = programs.byId(missed.programId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.hero),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy_rounded, color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Text('MISSED ON ${DateFormat('EEE d MMM').format(missed.date).toUpperCase()}',
                    style: AppText.eyebrow.copyWith(color: AppColors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.name.toUpperCase(), style: AppText.display(28)),
            const SizedBox(height: 4),
            Text(
              program == null
                  ? 'Do it today, or skip it.'
                  : 'Do it today and the rest of ${program.name} shifts along, so you stay in order.',
              style: AppText.muted,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Do it today',
                    onPressed: () async {
                      await programs.doMissedToday(missed, plans.schedules);
                      await plans.loadPlans();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    text: 'Skip',
                    variant: ButtonVariant.secondary,
                    onPressed: () async {
                      await programs.skipMissed(missed);
                      await plans.loadPlans();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's calories and protein; opens the nutrition screen.
class _FoodCard extends StatelessWidget {
  const _FoodCard();

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final targets = targetsFor(context.watch<ProfileProvider>());
    // The card always shows today, even if the nutrition screen was left on another day.
    final today = nutrition.isToday ? nutrition.totals : null;

    return AppCard(
      onTap: () async {
        if (!nutrition.isToday) await nutrition.setDay(DateTime.now());
        if (context.mounted) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NutritionScreen()));
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_rounded, color: AppColors.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FOOD TODAY', style: AppText.eyebrow),
                const SizedBox(height: 2),
                Text(
                  today == null
                      ? 'Log your meals'
                      : targets == null
                          ? '${today.kcal.round()} kcal · ${today.protein.round()} g protein'
                          : '${today.kcal.round()} / ${targets.kcal.round()} kcal · '
                              '${today.protein.round()} / ${targets.protein.round()} g protein',
                  style: AppText.strong,
                  maxLines: 2,
                ),
                if (targets != null && today != null) ...[
                  const SizedBox(height: 8),
                  ProgressBar(value: today.kcal / targets.kcal, height: 6),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
