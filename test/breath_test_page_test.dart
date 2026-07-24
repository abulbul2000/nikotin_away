import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('completing 3 attempts routes to RiskResultPage and calls service once',
      (tester) async {
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

    // Attempt 1: the only one requiring any taps to begin — every
    // attempt after this one auto-starts at the end of its preceding
    // rest interval (see the "auto-starts attempt 2/3" test below), since
    // by then the voice guide has already explained everything.

    // Tap 1: start the attempt (-> "sit and relax" step). No
    // pumpAndSettle from here through the deep-breath step: the breathing
    // circle animation now repeats indefinitely on both of these steps, so
    // settling would never terminate.
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap 2: same circle, now on "sit and relax" (-> "take a deep breath"
    // step).
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap 3: same circle, now on "take a deep breath" (-> "holding" step;
    // this is when the stopwatch and mic listening actually start).
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // The 5-second hold countdown elapses, then prompts "press Start".
    // Deliberately exactly 5s (not 6+): the prompt starts its own 1s
    // retry-reset grace window right as the countdown hits zero, so
    // pumping past 6s total risks the retry timer firing before the
    // test gets a chance to tap the button.
    await tester.pump(const Duration(seconds: 5));

    // Tap 4: confirm the hold (-> "exhale" active step directly; this is
    // when the visible counting and the give-up clock actually start).
    // No pumpAndSettle: the pulse animation has been repeating since the
    // hold began and won't stop until the attempt finishes. The "Başlat"
    // prompt is the same tappable circle as the seconds counter now, not a
    // separate button.
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap 5: finish the attempt manually (no real mic in the test
    // environment, so acoustic auto-detection never fires here).
    await tester.ensureVisible(circleFinder);
    await tester.tap(circleFinder);
    await tester.pump();

    // Attempts 2 and 3: no taps at all to *begin* them — the rest
    // interval's 20s countdown auto-starts the next attempt directly into
    // the "exhale" active step once it elapses (there's no real TTS in
    // the test environment, so nothing blocks on speech completion here).
    for (var i = 0; i < 2; i += 1) {
      await tester.pump(const Duration(seconds: 21));

      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
    }

    await tester.pumpAndSettle();

    expect(fakeService.callCount, 1);
    expect(find.byType(RiskResultPage), findsOneWidget);
  });

  testWidgets(
    'hold step retries cleanly if "Başlat" is not tapped in time, and still completes',
    (tester) async {
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
      final holdStartButtonFinder = find.byKey(
        const ValueKey('breath_hold_start_button'),
      );

      // No pumpAndSettle through sit-relax/deep-breath: the breathing
      // circle animation repeats indefinitely on both steps.
      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Let the 5-second hold countdown elapse -> prompts "Başlata basın".
      await tester.pump(const Duration(seconds: 5));
      expect(holdStartButtonFinder, findsOneWidget);

      // Deliberately don't tap it — let the full retry grace period pass
      // instead. The prompt should give up and restart the countdown
      // rather than leaving the attempt stuck on the prompt forever.
      await tester.pump(const Duration(seconds: 5));
      expect(
        holdStartButtonFinder,
        findsNothing,
        reason: 'a missed hold-start tap should reset back to counting down, '
            'not get stuck showing the prompt indefinitely',
      );

      // Second cycle: let it elapse again and this time actually tap it.
      await tester.pump(const Duration(seconds: 5));
      expect(holdStartButtonFinder, findsOneWidget);
      await tester.ensureVisible(holdStartButtonFinder);
      await tester.tap(holdStartButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Finish manually (no real mic in the test environment) and confirm
      // the retry cycle didn't leave the page in a broken state — a
      // single attempt still completes and reaches the rest interval.
      await tester.ensureVisible(circleFinder);
      await tester.tap(circleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirms the retry cycle didn't leave anything broken: no
      // exceptions, and still on the breath test flow (rest interval)
      // rather than any error screen.
      expect(tester.takeException(), isNull);
      expect(find.byType(BreathTestPage), findsOneWidget);
    },
  );
}
