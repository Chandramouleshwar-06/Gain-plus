import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/account/account_provider.dart';
import 'features/account/sync_coordinator.dart';
import 'firebase_options.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'features/workout/workout_provider.dart';
import 'features/plans/plans_provider.dart';
import 'features/plans/programs_provider.dart';
import 'features/exercise/exercise_provider.dart';
import 'features/progress/progress_provider.dart';
import 'features/profile/onboarding_screen.dart';
import 'features/profile/profile_provider.dart';
import 'features/reminders/reminder_sync.dart';
import 'features/nutrition/nutrition_provider.dart';
import 'features/settings/settings_provider.dart';
import 'navigation/app_shell.dart';
import 'navigation/nav_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for Windows or Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navBar,
  ));

  try {
    await DatabaseService.instance.database;
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  // Accounts are optional; if Firebase can't start, the app works signed out.
  var accountAvailable = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // The local database is the offline copy; no second cache in Firestore.
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    accountAvailable = true;
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
  }
  runApp(MyApp(accountAvailable: accountAvailable));
}

class MyApp extends StatelessWidget {
  final bool accountAvailable;

  const MyApp({super.key, this.accountAvailable = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider(available: accountAvailable)),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()..restore()),
        ChangeNotifierProvider(create: (_) => PlansProvider()..loadPlans()),
        ChangeNotifierProvider(create: (_) => ProgramsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()..loadExercises()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()..loadData()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Gain+',
        theme: AppTheme.darkTheme,
        home: const SyncCoordinator(child: _Root()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Shows onboarding until the profile is set up, then the app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    if (!profile.loaded) return const Scaffold();
    return profile.needsOnboarding ? const OnboardingScreen() : const ReminderSync(child: AppShell());
  }
}
