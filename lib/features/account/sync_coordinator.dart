import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sync/sync_engine.dart';
import '../activity/activity_provider.dart';
import '../exercise/exercise_provider.dart';
import '../health/health_screen.dart';
import '../nutrition/nutrition_provider.dart';
import '../plans/plans_provider.dart';
import '../plans/programs_provider.dart';
import '../profile/profile_provider.dart';
import '../progress/progress_provider.dart';
import '../workout/workout_provider.dart';
import 'account_provider.dart';

/// Keeps the account in sync in the background: after sign-in, when the
/// app returns to the foreground, when the connection comes back, and a
/// few seconds after local changes. Reloads every screen after a sync
/// brings in data from another device.
class SyncCoordinator extends StatefulWidget {
  final Widget child;
  const SyncCoordinator({super.key, required this.child});

  @override
  State<SyncCoordinator> createState() => _SyncCoordinatorState();
}

class _SyncCoordinatorState extends State<SyncCoordinator> with WidgetsBindingObserver {
  late final AccountProvider _account;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  String? _lastSignature;
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    _account = context.read<AccountProvider>();
    _wasSignedIn = _account.signedIn;
    _account.onDataPulled = _reloadAll;
    WidgetsBinding.instance.addObserver(this);
    // Steps, sleep and new workouts from Health Connect, if connected.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncHealth(context);
    });
    if (_account.available) {
      try {
        _connectivity = Connectivity().onConnectivityChanged.listen((results) {
          if (!results.contains(ConnectivityResult.none)) _syncSoon(const Duration(seconds: 2));
        });
      } catch (e) {
        debugPrint('Connectivity updates unavailable: $e');
      }
      if (_account.signedIn) _syncSoon(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _debounce?.cancel();
    _account.onDataPulled = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSoon(const Duration(seconds: 1));
      syncHealth(context);
    }
  }

  void _syncSoon(Duration delay, {bool onlyIfPending = false}) {
    if (!_account.signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () async {
      if (onlyIfPending && await SyncEngine.pendingChanges() == 0) return;
      await _account.syncNow();
    });
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    final signedOut = _wasSignedIn && !_account.signedIn;
    _wasSignedIn = _account.signedIn;
    if (signedOut) await context.read<WorkoutProvider>().discardWorkout();
    if (!mounted) return;
    await Future.wait([
      context.read<ExerciseProvider>().loadExercises(),
      context.read<PlansProvider>().loadPlans(),
      context.read<ProgramsProvider>().load(),
      context.read<ProgressProvider>().loadData(),
      context.read<ProfileProvider>().load(),
      context.read<NutritionProvider>().load(),
      context.read<ActivityProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    if (account.signedIn && !_wasSignedIn) _wasSignedIn = true;

    // Local edits show up as provider changes; upload them shortly after.
    final signature = [
      context.watch<ProgressProvider>().totalWorkouts,
      context.watch<ProgressProvider>().totalVolume,
      context.watch<PlansProvider>().plans.length,
      context.watch<PlansProvider>().schedules.length,
      context.watch<ProgramsProvider>().programs.length,
      context.watch<ExerciseProvider>().exercises.length,
      context.watch<ProfileProvider>().profile?.toMap().toString(),
      context.watch<ProfileProvider>().goals.length,
      context.watch<ProfileProvider>().bodyWeights.length,
      context.watch<NutritionProvider>().logs.length,
      context.watch<NutritionProvider>().savedFoods.length,
      context.watch<ActivityProvider>().recent.length,
      context.watch<ActivityProvider>().burnedToday,
    ].join('|');
    if (signature != _lastSignature) {
      _lastSignature = signature;
      _syncSoon(const Duration(seconds: 8), onlyIfPending: true);
    }
    return widget.child;
  }
}
