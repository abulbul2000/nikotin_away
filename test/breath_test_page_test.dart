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

    for (var i = 0; i < 3; i += 1) {
      final buttonFinder = find.byType(ElevatedButton);
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      if (i < 2) {
        await tester.pump(const Duration(seconds: 20));
      }
    }

    await tester.pumpAndSettle();

    expect(fakeService.callCount, 1);
    expect(find.byType(RiskResultPage), findsOneWidget);
  });
}
