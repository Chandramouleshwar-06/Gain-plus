import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gain_plus/services/database_service.dart';
import 'package:gain_plus/features/exercise/exercise_guide_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// Opens every tab and a workout on a small phone screen. Layout
/// overflows (the yellow/black "RIGHT OVERFLOWED" bars) fail the test.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _loadAppFonts();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetDatabase();
  });
  tearDown(() => DatabaseService.instance.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      // Let real database work finish, then render.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Like [settle], but keeps going (up to ~5 s) until [finder] matches.
  Future<void> settleUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Large system text is where fixed-height layouts break, so run twice.
  for (final textScale in [1.0, 1.3]) {
    testWidgets(
      'every tab and the workout screen lay out on a 360dp phone (text x)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(const MyApp());
        await settleUntil(tester, find.text("WHAT'S YOUR NAME?"));

        // Onboarding on a fresh install.
        expect(find.text("WHAT'S YOUR NAME?"), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'CR');
        await tester.pump();
        await tester.tap(find.text('CONTINUE'));
        await settle(tester);
        await tester.tap(find.text('GET STRONGER'));
        await tester.pump();
        await tester.tap(find.text('CONTINUE'));
        await settle(tester);
        await tester.tap(find.byTooltip('More'));
        await tester.tap(find.text('CONTINUE'));
        await settle(tester);
        // Home gym: no machines or cables, so some exercises get flagged.
        expect(find.text('WHERE DO YOU TRAIN?'), findsOneWidget);
        await tester.tap(find.text('HOME GYM'));
        await tester.pump();
        await tester.tap(find.text('CONTINUE'));
        await settle(tester);
        await tester.tap(find.text("LET'S GO"));
        await settle(tester);

        expect(find.text("LET'S GO, CR"), findsOneWidget);
        expect(
          find.text('0/4'),
          findsOneWidget,
          reason: 'weekly target from onboarding',
        );

        // Nutrition: Home card -> screen -> food search -> portion sheet.
        await tester.dragUntilVisible(
          find.text('FOOD TODAY'),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -250),
        );
        await tester.tap(find.text('FOOD TODAY'));
        await settle(tester);
        expect(find.text('NUTRITION'), findsOneWidget);
        expect(find.text('SET UP YOUR TARGETS'), findsOneWidget);
        await tester.tap(find.byTooltip('Add to Breakfast'));
        await settle(tester);
        expect(find.text('COMMON FOODS'), findsOneWidget);
        await tester.tap(find.text('Roti / chapati'));
        await settle(tester);
        await tester.tap(find.text('ADD TO BREAKFAST').last); // the sheet's button, not the title
        await settle(tester);
        await settleUntil(tester, find.text('NUTRITION'));
        expect(find.byType(Dismissible), findsOneWidget, reason: 'roti logged once under breakfast');
        await settle(tester); // let the food search screen finish closing
        expect(find.text('BURNED'), findsOneWidget);
        await tester.pageBack();
        await settle(tester);

        // Log a run from the Home card; its calories show up there.
        await tester.dragUntilVisible(
          find.text('MOVE TODAY'),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -250),
        );
        await tester.tap(find.byTooltip('Log activity'));
        await settle(tester);
        expect(find.text('LOG ACTIVITY'), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const Key('activity-distance')),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -200),
        );
        await tester.enterText(find.byKey(const Key('activity-distance')), '5');
        await tester.pump();
        expect(find.textContaining('per km'), findsOneWidget, reason: 'pace from 5 km in 30 min');
        await tester.dragUntilVisible(
          find.text('SAVE ACTIVITY'),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -250),
        );
        await tester.tap(find.text('SAVE ACTIVITY'));
        await settleUntil(tester, find.textContaining('kcal burned'));
        expect(find.textContaining('kcal burned'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text("LET'S GO, CR"),
          find.byType(ListView).hitTestable().first,
          const Offset(0, 250),
        );
        await settle(tester);

        await tester.tap(find.text('Train'));
        await settle(tester);
        expect(find.text('CALISTHENICS BASIC'), findsOneWidget);

        // Open and cancel the New plan dialog (it used to crash while closing).
        await tester.tap(find.text('New plan'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).last, 'Test');
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(find.text('Create'), findsNothing);

        // The program editor lays out too.
        await tester.tap(find.text('New program'));
        await settle(tester);
        expect(find.text('NEW PROGRAM'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('START PROGRAM'),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -300),
        );
        await tester.pageBack();
        await settle(tester);

        await tester.tap(find.text('CALISTHENICS BASIC'));
        await settle(tester);
        expect(find.text('Push Ups'), findsOneWidget);
        await tester.tapAt(const Offset(180, 20)); // close the sheet
        await settle(tester);

        await tester.tap(find.text('Schedule'));
        await settle(tester);
        await tester.tap(find.text('Exercises'));
        await settle(tester);
        expect(find.text('Search exercises'), findsOneWidget);

        await tester.tap(find.text('Progress'));
        await settle(tester);
        await tester.tap(find.text('Profile'));
        await settle(tester);
        // Measurements: log a waist size from the Body screen.
        await tester.dragUntilVisible(
          find.text('Measurements & photos'),
          find.byType(ListView).first,
          const Offset(0, -200),
        );
        await tester.ensureVisible(find.text('Measurements & photos'));
        await settle(tester);
        await tester.tap(find.text('Measurements & photos'));
        await settle(tester);
        expect(find.text('BODY'), findsOneWidget);
        await tester.tap(find.text('Log').first);
        await settle(tester);
        await tester.enterText(find.byKey(const Key('measure-waist')), '84');
        await tester.pump();
        await tester.dragUntilVisible(
          find.text('SAVE'),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        await tester.tap(find.text('SAVE'));
        await settleUntil(tester, find.text('84 cm'));
        expect(find.text('84 cm'), findsOneWidget);
        await tester.pageBack();
        await settle(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
        await settle(tester);

        // Health: tests run off-device, so it shows as not available here.
        await tester.dragUntilVisible(
          find.text('Health Connect'),
          find.byType(ListView).first,
          const Offset(0, -200),
        );
        await tester.tap(find.text('Health Connect'));
        await settle(tester);
        expect(find.text('HEALTH APPS'), findsOneWidget);
        await tester.pageBack();
        await settle(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await settle(tester);
        await tester.tap(find.text('Notifications'));
        await settle(tester);
        expect(find.text('Weekly recap'), findsOneWidget);
        await tester.pageBack();
        await settle(tester);

        await tester.tap(find.text('Home'));
        await settle(tester);
        await tester.tap(find.text('CHOOSE A WORKOUT'));
        await settle(tester);
        await tester.tap(find.text('Legs (Quads/Hams/Calves)'));
        await settle(tester);
        expect(find.text('FINISH'), findsOneWidget);
        expect(find.text('SQUAT (BARBELL)'), findsOneWidget);
        // Leg Press needs a machine, which a home gym doesn't have.
        expect(find.textContaining('Needs a machine'), findsWidgets);

        // How-to for the first exercise, from its menu.
        await tester.tap(find.byTooltip('Exercise options').first);
        await settle(tester);
        await tester.tap(find.text('How to do it'));
        await settle(tester);
        expect(find.text('HOW TO DO IT'), findsOneWidget);
        expect(find.textContaining('Works: Quads'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Watch a demo'),
          find.descendant(of: find.byType(ExerciseGuideScreen), matching: find.byType(ListView)),
          const Offset(0, -300),
        );
        await tester.pageBack();
        await settle(tester);

        // Log 100 kg x 5 on the first set; ticking it starts the rest timer.
        await tester.enterText(find.byType(TextField).at(0), '100');
        await tester.enterText(find.byType(TextField).at(1), '5');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Set 1 done').first);
        await settle(tester);
        expect(find.text('REST'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await settle(tester);
        expect(find.text('REST'), findsNothing);

        // Minimize: the in-progress bar shows above the tabs; tap it to come back.
        await tester.tap(find.byTooltip('Minimize'));
        await settle(tester);
        await tester.tap(find.text('LEGS (QUADS/HAMS/CALVES)').last);
        await settle(tester);

        // Finish, then the lift shows on Progress with its chart screen.
        await tester.tap(find.text('FINISH'));
        await settle(tester);
        await tester.tap(find.text('Finish'));
        await settle(tester);
        await settleUntil(tester, find.text('ACHIEVEMENT UNLOCKED'));
        expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
        expect(find.text('FIRST REP'), findsOneWidget);
        await tester.tap(find.text('NICE'));
        await settle(tester);
        await tester.tap(find.text('Progress'));
        await settle(tester);
        expect(find.text('WEEKLY VOLUME'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Squat (Barbell)'),
          find.byType(ListView).hitTestable().first,
          const Offset(0, -250),
        );
        await settle(tester);
        await tester.tap(find.text('Squat (Barbell)'));
        await settle(tester);
        expect(find.text('SQUAT (BARBELL)'), findsOneWidget);
        expect(
          find.text('Do this exercise one more time to see a trend.'),
          findsOneWidget,
        );
      },
    );
  }
}

/// Loads the bundled Barlow fonts so text is measured as on a phone
/// (tests otherwise use a placeholder font with square glyphs).
Future<void> _loadAppFonts() async {
  const families = {
    'Barlow': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'BarlowCondensed': ['SemiBold', 'Bold', 'ExtraBold'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      final bytes = File(
        'assets/fonts/${entry.key}-$weight.ttf',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
