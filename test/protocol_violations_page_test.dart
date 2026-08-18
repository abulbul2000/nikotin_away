import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/protocol_violations_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call — this test seeds data through
/// one StorageService instance and reads it back through a second one
/// (ProtocolViolationsPage's own internal instance), which land in
/// different, disconnected sqlite files if this minted a fresh temp dir per
/// call.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_protocol_violations')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Regression coverage: this page used to show ProtocolViolation.type and
/// .source verbatim (e.g. "willpower_weakness", "app_flow") — internal
/// canonical codes, never routed through context.t() — regardless of the
/// user's selected language. Same root cause as sleep_routine_page_test
/// .dart/health_metrics_page_test.dart: initState-driven StorageService I/O
/// needs LiveTestWidgetsFlutterBinding, or pumpAndSettle() hangs forever.
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

  Widget wrap(Widget child, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en'), Locale('de')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets(
    'a known violation type/source is shown translated, not as a raw code',
    (tester) async {
      final storage = StorageService();
      await storage.saveProtocolViolation(
        type: 'willpower_weakness',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: 'Yürüyüşe çık',
        details: 'Task outcome marked as not completed by user.',
      );

      await tester.pumpWidget(
        wrap(const ProtocolViolationsPage(), const Locale('de')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('willpower_weakness'), findsNothing);
      expect(find.text('app_flow'), findsNothing);
      expect(find.textContaining('nicht abgeschlossen'), findsOneWidget);
      expect(find.textContaining('App-Ablauf'), findsOneWidget);
    },
  );

  testWidgets(
    'the native watchdog no_response_10_min type is also translated',
    (tester) async {
      final storage = StorageService();
      await storage.saveProtocolViolation(
        type: 'no_response_10_min',
        severity: 'high',
        source: 'queued_import',
        taskTitle: 'Görevi ertele',
        details: 'All 3 retry attempts passed with no response.',
      );

      await tester.pumpWidget(
        wrap(const ProtocolViolationsPage(), const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('no_response_10_min'), findsNothing);
      expect(find.text('queued_import'), findsNothing);
      expect(find.textContaining('unanswered for 10 minutes'), findsOneWidget);
    },
  );

  testWidgets(
    'an unknown/future violation type falls back to the raw code instead of crashing',
    (tester) async {
      final storage = StorageService();
      await storage.saveProtocolViolation(
        type: 'some_future_type',
        severity: 'low',
        source: 'some_future_source',
        taskTitle: null,
        details: 'placeholder',
      );

      await tester.pumpWidget(
        wrap(const ProtocolViolationsPage(), const Locale('tr')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('some_future_type'), findsOneWidget);
    },
  );
}
