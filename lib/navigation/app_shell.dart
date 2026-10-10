import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/train/train_screen.dart';
import '../features/workout/workout_launcher.dart';
import '../features/workout/workout_provider.dart';
import '../theme/app_theme.dart';
import 'nav_provider.dart';

/// The four main tabs plus a bar for the workout in progress.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    return Scaffold(
      body: IndexedStack(
        index: nav.tab.index,
        children: const [
          HomeScreen(),
          TrainScreen(),
          ProgressScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutBar(),
          _NavBar(current: nav.tab, onTap: nav.goTo),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onTap;

  const _NavBar({required this.current, required this.onTap});

  static const _items = [
    (AppTab.home, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (AppTab.train, Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Train'),
    (AppTab.progress, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
    (AppTab.profile, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: Color(0xFF222225))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final (tab, icon, activeIcon, label) in _items)
                Expanded(
                  child: Semantics(
                    selected: tab == current,
                    button: true,
                    child: InkResponse(
                      onTap: () => onTap(tab),
                      radius: 36,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tab == current ? activeIcon : icon,
                              color: tab == current ? AppColors.lime : AppColors.textMuted, size: 26),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: tab == current ? FontWeight.w700 : FontWeight.w600,
                              color: tab == current ? AppColors.lime : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown above the tabs while a workout is running; tap to go back to it.
class _ActiveWorkoutBar extends StatelessWidget {
  const _ActiveWorkoutBar();

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    if (!workout.isWorkoutActive) return const SizedBox.shrink();

    return Material(
      color: AppColors.lime,
      child: InkWell(
        onTap: () => openActiveWorkout(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.fitness_center_rounded, color: AppColors.onLime, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  workout.activePlanName.toUpperCase(),
                  style: AppText.display(18, color: AppColors.onLime, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ElapsedText(startTime: workout.startTime!),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.onLime),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElapsedText extends StatefulWidget {
  final DateTime startTime;
  const _ElapsedText({required this.startTime});

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatElapsed(DateTime.now().difference(widget.startTime)),
      style: AppText.display(18, color: AppColors.onLime, weight: FontWeight.w700)
          .copyWith(fontFeatures: AppText.tabular),
    );
  }
}
