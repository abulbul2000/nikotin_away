import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/weekly_survey_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_weekly_survey').path;
  }
}

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSurvey(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WeeklySurveyPage(),
      ),
    );
    await settle(tester);
  }

  testWidgets('there is no mode selector — one survey, not two', (
    tester,
  ) async {
    await openSurvey(tester);

    // The detailed mode was ~870 lines nobody opted into, and the quick mode
    // filled its fields with constants. Both are gone.
    expect(find.byType(ChoiceChip), findsWidgets); // severity chips exist
    expect(find.text('Detaylı'), findsNothing);
    expect(find.text('Hızlı'), findsNothing);
  });

  testWidgets('withdrawal symptoms are asked, not inferred from mood', (
    tester,
  ) async {
    await openSurvey(tester);

    // Each of the five used to be written as `isBad ? 2 : 1` — five numbers
    // carrying one bit of information from a mood dropdown.
    for (final key in [
      'irritability',
      'anxiety',
      'sleepProblem',
      'concentrationProblem',
      'appetiteIncrease',
    ]) {
      expect(
        find.byKey(ValueKey('weeklyWithdrawal_$key')),
        findsOneWidget,
        reason: '$key must be asked',
      );
    }
  });

  testWidgets('all seven triggers are asked', (tester) async {
    await openSurvey(tester);

    // Five of the seven day-counts were hardcoded (coffee 3, meal 3,
    // driving 2, phone 3, social 3).
    for (final key in [
      'coffee',
      'meal',
      'driving',
      'stress',
      'phone',
      'social',
      'alcohol',
    ]) {
      expect(
        find.byKey(ValueKey('weeklyTrigger_$key')),
        findsOneWidget,
        reason: '$key must be asked',
      );
    }
  });

  testWidgets('mMRC opens at "no breathlessness", in plain language', (
    tester,
  ) async {
    await openSurvey(tester);

    // It used to be a dropdown of bare numbers 1-5 defaulting to 2, so a user
    // who never touched it was recorded as breathless on the flat.
    expect(find.byKey(const ValueKey('mmrc_0')), findsOneWidget);
    expect(find.text('Nefes darlığı yaşamıyorum.'), findsOneWidget);

    final firstOption = tester.widget<RadioListTile<int>>(
      find.byKey(const ValueKey('mmrc_0')),
    );
    expect(firstOption.value, 0);
  });

  testWidgets('breathing questions offer worded levels, not a 0-5 number', (
    tester,
  ) async {
    await openSurvey(tester);

    // "Öksürük (0-5)" left the user to invent what a 3 meant.
    expect(find.byKey(const ValueKey('weeklyCough_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('weeklyCough_5')), findsOneWidget);
    expect(find.textContaining('(0-5)'), findsNothing);
  });

  testWidgets('sleep and energy impact are part of the breathing check', (
    tester,
  ) async {
    await openSurvey(tester);

    expect(find.byKey(const ValueKey('weeklySleepImpact_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('weeklyEnergyImpact_0')), findsOneWidget);
  });

  testWidgets('night breathlessness is asked in nights, not a day count', (
    tester,
  ) async {
    await openSurvey(tester);

    // A 0-7 slider asks the user to reconstruct a week they weren't counting.
    expect(
      find.byKey(const ValueKey('weeklyNightBreathlessness_0')),
      findsOneWidget,
    );
    expect(find.text('Bir iki gece'), findsOneWidget);
    expect(find.text('Neredeyse her gece'), findsOneWidget);
  });
}
