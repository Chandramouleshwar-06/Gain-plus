import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'features/workout/workout_provider.dart';
import 'features/plans/plans_provider.dart';
import 'features/exercise/exercise_provider.dart';
import 'features/progress/progress_provider.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()..restore()),
        ChangeNotifierProvider(create: (_) => PlansProvider()..loadPlans()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()..loadExercises()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()..loadData()),
      ],
      child: MaterialApp(
        title: 'Gain+',
        theme: AppTheme.darkTheme,
        home: const AppShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
