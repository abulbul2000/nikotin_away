import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/reduction_progress.dart';
import 'package:no_smoke/pages/achievements_page.dart';
import 'package:no_smoke/pages/medications_page.dart';
import 'package:no_smoke/pages/weekly_survey_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_overflow').path;
  }
}

/// The smallest screen the app still supports. Translations run longer than
/// Turkish — German, Russian and Tamil especially — so a row that fits in
/// Turkish on a big phone is exactly where overflow shows up first.
const smallScreen = Size(320, 568);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, null);
  });

  Future<void> useSmallScreen(WidgetTester tester) async {
    tester.view.physicalSize = smallScreen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> render(
    WidgetTester tester,
    Widget child, {
    required String locale,
  }) async {
    await useSmallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: [Locale(locale)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // A RenderFlex overflow raises a FlutterError during layout, which the test
  // binding records — so simply rendering is the assertion.
  for (final locale in ['tr', 'de', 'ru', 'ta', 'ar']) {
    testWidgets('weekly survey fits a 320x568 screen in $locale', (
      tester,
    ) async {
      await render(tester, const WeeklySurveyPage(), locale: locale);
      expect(tester.takeException(), isNull);
    });

    testWidgets('badge grid fits a 320x568 screen in $locale', (tester) async {
      await render(
        tester,
        const AchievementsPage(
          progress: ReductionProgress(
            targetStreakDays: 12,
            cigarettesAvoided: 340,
            naturalIntervalMinutes: 45,
            currentBarrierMinutes: 71,
            dailyTarget: 8,
            baselineDaily: 20,
            loggedToday: 3,
            evidenceDays: 30,
          ),
        ),
        locale: locale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('medication editor fits a 320x568 screen in $locale', (
      tester,
    ) async {
      await render(tester, const MedicationsPage(), locale: locale);
      await tester.tap(find.byType(FloatingActionButton));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
