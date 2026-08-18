import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/pages/health_metrics_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call — this test seeds data through
/// one StorageService instance and reads it back through a second one
/// (HealthMetricsPage's own internal instance), which land in different,
/// disconnected sqlite files if this minted a fresh temp dir per call.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_health_metrics')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Regression coverage for a real overflow risk found in the "recent tests"
/// list: neither the date/exhale/inhale Column nor the risk-level Text was
/// wrapped in Expanded/Flexible, so a long risk-level string (a plausible
/// stand-in for a translation longer than Turkish — CLAUDE.md notes German/
/// Russian/Tamil run noticeably longer) had nowhere to shrink and threw a
/// RenderFlex overflow at layout time. This page is deliberately excluded
/// from multilingual_smoke_test.dart (needs a live, non-empty
/// StorageService to render its data-driven list), so it gets its own
/// narrow widget test instead.
// The default TestWidgetsFlutterBinding runs on paused/fake time, which
// never gets signaled by a real native FFI completion callback (sqflite's,
// arriving on a real OS thread) — so HealthMetricsPage's initState-driven
// _loadBreathTests future never resolves and pumpAndSettle() hangs forever
// with no exception. LiveTestWidgetsFlutterBinding uses real wall-clock
// time instead and does not hit this (same root cause documented in
// sleep_routine_page_test.dart).
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
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets(
    'a long risk-level label in the recent-tests row does not overflow on a small screen',
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
          riskScore: 72,
          // Deliberately longer than any real riskLevel string this app
          // produces — stands in for a worst-case long translation so the
          // test doesn't depend on which language happens to be longest.
          riskLevel: 'AŞIRI YÜKSEK RİSK SEVİYESİ ÇOK UZUN BİR METİN',
        ),
      );

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const HealthMetricsPage(name: 'Ada')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Appears twice by design: once in the top "riskScore" metric card's
      // subtitle ("Seviye: ..."), once as the risk-level Text in the
      // recent-tests row this test targets. What matters is that laying
      // both out at 320px did not throw — already checked above via
      // takeException — this just confirms the row actually rendered.
      expect(find.textContaining('AŞIRI YÜKSEK'), findsNWidgets(2));
    },
  );
}
