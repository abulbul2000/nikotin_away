import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/pages/personal_progress_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call — this test seeds data through
/// one StorageService instance and reads it back through a second one
/// (PersonalProgressPage's own internal instance), which land in different,
/// disconnected sqlite files if this minted a fresh temp dir per call.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_personal_progress')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Regression coverage: several strings on this page hardcoded Turkish text
/// or ad-hoc abbreviations ("sn", "Paket", "Yuk", "Min"/"Max"/"Son")
/// directly into interpolated strings instead of routing them through
/// context.t(), so a non-Turkish user saw Turkish fragments mixed into
/// their own language's UI. Needs LiveTestWidgetsFlutterBinding because
/// _loadData's real StorageService I/O in initState never resolves under
/// the default fake-clock binding (same root cause documented in
/// sleep_routine_page_test.dart/health_metrics_page_test.dart).
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    await StorageService().clearAllData();
  });

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets(
    'the breath-delta row, weekly-history pack label, and chart captions are translated, not hardcoded Turkish',
    (tester) async {
      final storage = StorageService();
      await storage.saveSurveyRecord(
        SurveyRecord(
          id: 'breath_1',
          completedAt: DateTime(2024, 1, 1),
          type: 'breath_test',
          title: 'Nefes Testi',
          name: 'Ada',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 8,
          inhaleTestSeconds: 6,
          riskScore: 50,
          riskLevel: 'medium',
        ),
      );
      await storage.saveSurveyRecord(
        SurveyRecord(
          id: 'breath_2',
          completedAt: DateTime(2024, 1, 8),
          type: 'breath_test',
          title: 'Nefes Testi',
          name: 'Ada',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 12,
          inhaleTestSeconds: 10,
          riskScore: 45,
          riskLevel: 'medium',
        ),
      );
      await storage.saveSurveyRecord(
        SurveyRecord(
          id: 'weekly_1',
          completedAt: DateTime(2024, 1, 5),
          type: 'weekly',
          title: 'Haftalık Anket',
          name: 'Ada',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 0,
          inhaleTestSeconds: 0,
          riskScore: 40,
          riskLevel: 'medium',
        ),
      );

      await tester.pumpWidget(wrap(const PersonalProgressPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The breath-delta row used to end in the literal Turkish
      // abbreviation " sn" regardless of locale.
      expect(find.textContaining(' sn'), findsNothing);
      expect(find.textContaining(' sec'), findsOneWidget);

      // The chart captions are further down the ListView than the initial
      // layout mounts, and scrolling too far unmounts them again (ListView
      // only keeps a small cache extent around the viewport) — scroll in
      // small steps and assert as soon as the target text is reachable.
      for (var i = 0; i < 6; i++) {
        if (find.textContaining('Latest:').evaluate().isNotEmpty) break;
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }

      // The mini-chart caption used to hardcode "Min"/"Max"/"Son" — "Son"
      // (Turkish for "latest") is the one that actually differs in
      // English ("Latest").
      expect(find.textContaining('Son:'), findsNothing);
      expect(find.textContaining('Latest:'), findsWidgets);

      for (var i = 0; i < 10; i++) {
        if (find.textContaining('Pack:').evaluate().isNotEmpty) break;
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }

      // The weekly-history row used to hardcode "Paket:" as a label even
      // in an English-locale build.
      expect(find.textContaining('Paket:'), findsNothing);
      expect(find.textContaining('Pack:'), findsOneWidget);
    },
  );

  testWidgets(
    'a respiratory alert with an elevated burden shows a translated load label, not the raw Turkish "Yuk"',
    (tester) async {
      final storage = StorageService();
      await storage.saveSurveyRecord(
        SurveyRecord(
          id: 'weekly_1',
          completedAt: DateTime(2024, 1, 5),
          type: 'weekly',
          title: 'Haftalık Anket',
          name: 'Ada',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 0,
          inhaleTestSeconds: 0,
          riskScore: 60,
          riskLevel: 'high',
        ),
      );
      // mmrcGrade=5 and a maxed-out catLike total push calculateBurden well
      // past the 65 "clinical_review_recommended" threshold, so this record
      // is guaranteed to surface in the respiratory alert timeline.
      await storage.saveSurveyDetail(
        recordId: 'weekly_1',
        triggers: const [],
        healthConditions: const [],
        weeklyPayload: {
          'respiratory': {
            'mmrcGrade': 5,
            'catLike': {
              'cough': 5,
              'phlegm': 5,
              'chestTightness': 5,
              'breathlessnessStairs': 5,
              'activityLimitation': 5,
              'confidenceLeavingHome': 5,
              'sleepQualityResp': 5,
              'energyLevelResp': 5,
            },
            'warningSigns': {
              'increasedNightBreathlessnessDays': 7,
              'sputumColorChangeDays': 7,
            },
          },
        },
      );

      await tester.pumpWidget(wrap(const PersonalProgressPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (var i = 0; i < 10; i++) {
        if (find.textContaining('Load:').evaluate().isNotEmpty) break;
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Yuk:'), findsNothing);
      expect(find.textContaining('Load:'), findsWidgets);
    },
  );
}
