import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../navigation/nav_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../exercise/exercise_screen.dart';
import '../plans/plans_screen.dart';
import '../plans/workout_schedule_screen.dart';

/// Plans, schedule and the exercise library.
class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final NavProvider _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavProvider>();
    _tabs = TabController(length: TrainSection.values.length, vsync: this, initialIndex: _nav.trainSection.index);
    _tabs.addListener(() => _nav.trainSection = TrainSection.values[_tabs.index]);
    _nav.addListener(_syncFromNav);
  }

  /// Another screen asked for a specific section (e.g. "Go to Train > Plans").
  void _syncFromNav() {
    if (_tabs.index != _nav.trainSection.index) _tabs.animateTo(_nav.trainSection.index);
  }

  @override
  void dispose() {
    _nav.removeListener(_syncFromNav);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Train'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                child: TabBar(
                  controller: _tabs,
                  tabs: const [Tab(text: 'Plans'), Tab(text: 'Schedule'), Tab(text: 'Exercises')],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [PlansView(), ScheduleView(), ExercisesView()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
