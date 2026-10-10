import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gain_plus/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gain_plus/services/database_service.dart';
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
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Like [settle], but keeps going (up to ~5 s) until [finder] matches.
  Future<void> settleUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('every tab and the workout screen lay out on a 360dp phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await settle(tester);

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
    await tester.tap(find.text("LET'S GO"));
    await settle(tester);

    expect(find.text("LET'S GO, CR"), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget, reason: 'weekly target from onboarding');

    await tester.tap(find.text('Train'));
    await settle(tester);
    expect(find.text('CALISTHENICS BASIC'), findsOneWidget);

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
    expect(find.text('Do this exercise one more time to see a trend.'), findsOneWidget);
  });
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
      final bytes = File('assets/fonts/${entry.key}-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
