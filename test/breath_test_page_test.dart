import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
import 'package:no_smoke/engines/wheeze_detection_engine.dart';
import 'package:no_smoke/models/breath_test_result.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/pages/breath_test_page.dart';
import 'package:no_smoke/pages/risk_result_page.dart';
import 'package:no_smoke/services/breath_test_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_breath_test').path;
  }
}

class _FakeBreathTestService extends BreathTestService {
  int callCount = 0;

  @override
  Future<ProcessedBreathTest> processBreathTest({
    required String name,
    required String packsPerDay,
    required double holdDuration,
    required double blowDuration,
    required double blowStability,
    required double blowIntensity,
    SpirometryEstimate? spirometry,
    WheezeAnalysis? wheeze,
    DateTime? completedAt,
    String title = 'Nefes Testi',
  }) async {
    callCount += 1;
    final now = completedAt ?? DateTime(2026, 1, 1);
    return ProcessedBreathTest(
      breathResult: BreathTestResult(
        id: 'fake',
        createdAt: now,
        holdDuration: holdDuration,
        blowDuration: blowDuration,
        blowIntensity: blowIntensity,
        blowStability: blowStability,
        holdRisk: 40,
        blowRisk: 40,
        intensityRisk: 40,
        stabilityRisk: 40,
        breathScore: 40,
        riskContribution: 8,
      ),
      surveyRecord: SurveyRecord(
        id: 's1',
        completedAt: now,
        type: 'breath_test',
        title: title,
        name: name,
        packsPerDay: packsPerDay,
        exhaleTestSeconds: holdDuration.round(),
        inhaleTestSeconds: blowDuration.round(),
        riskScore: 42,
        riskLevel: 'ORTA',
      ),
      finalRiskScore: 42,
      finalRiskLevel: 'ORTA',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  testWidgets('completing all 3 required attempts (each user-paced through '
      'sit-relax/deep-breath, auto-paced through the hold countdown) routes '
      'to RiskResultPage and calls service once', (tester) async {
    final fakeService = _FakeBreathTestService();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BreathTestPage(
          name: 'Ada',
          packsPerDay: '1 paket',
          breathTestService: fakeService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final circleFinder = find.byKey(const ValueKey('breath_timer_circle'));

    // Tap 1: starts attempt 1 (-> "sit and relax" step).
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    // sit-relax -> deep-breath: user taps "Devam" themselves, no waiting.
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    // deep-breath -> holding: user taps "Devam" again; this is when the
    // stopwatch and mic listening actually start.
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    // The 3-second hold countdown elapses on its own and auto-advances
    // straight into exhale — no tap needed.
    for (var s = 0; s < 3; s += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 50));

    // Finish attempt 1 manually (no real mic in the test environment, so
    // acoustic auto-detection never fires here). This starts the 20s rest
    // interval leading into attempt 2.
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    // Attempts 2 and 3: each is preceded by a 20s rest interval which, once
    // elapsed, auto-starts the next attempt (_beginAutoMeasuredAttempt) with
    // no tap needed — it still walks through sit-relax/deep-breath/hold/
    // exhale exactly like attempt 1 did, just without the initial start tap.
    for (var attempt = 2; attempt <= 3; attempt += 1) {
      for (var s = 0; s < 20; s += 1) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 50));

      // sit-relax -> deep-breath -> holding: user taps Devam twice.
      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();

      for (var s = 0; s < 3; s += 1) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      if (attempt == 3) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    expect(fakeService.callCount, 1);
    expect(find.byType(RiskResultPage), findsOneWidget);
  });

  testWidgets('backgrounding the app mid-attempt discards it and shows a '
      'snackbar rather than silently keeping stale state', (tester) async {
    final fakeService = _FakeBreathTestService();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BreathTestPage(
          name: 'Ada',
          packsPerDay: '1 paket',
          breathTestService: fakeService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final circleFinder = find.byKey(const ValueKey('breath_timer_circle'));
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
