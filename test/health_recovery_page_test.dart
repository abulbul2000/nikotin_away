import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/smoking_event.dart';
import 'package:no_smoke/pages/health_recovery_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call — this test seeds data through
/// one StorageService instance and reads it back through a second one
/// (HealthRecoveryPage's own internal instance), which land in different,
/// disconnected sqlite files if this minted a fresh temp dir per call.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_health_recovery')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// HealthRecoveryPage is deliberately excluded from multilingual_smoke_test
/// .dart — it now loads its own last-logged-cigarette timestamp via
/// StorageService rather than taking a synchronous quitDate constructor
/// param, so it needs the same live-database + LiveTestWidgetsFlutterBinding
/// setup as health_metrics_page_test.dart (see that file's doc comment for
/// the root cause: the default TestWidgetsFlutterBinding's fake clock never
/// lets real sqflite FFI I/O resolve, so pumpAndSettle() would hang forever
/// with no exception under it).
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
    'with no cigarette ever logged, no milestone is claimed reached',
    (tester) async {
      // Regression coverage for the bug this replaced: computeProgress used
      // to measure elapsed time from a fixed quitDate regardless of
      // evidence, so a page shown to a brand-new user with nothing logged
      // yet would still claim "20 minutes smoke-free" milestones reached
      // purely from wall-clock time since some arbitrary date.
      await tester.pumpWidget(wrap(const HealthRecoveryPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    },
  );

  testWidgets(
    'a cigarette logged 30 minutes ago reaches only the first milestone, not later ones',
    (tester) async {
      final storage = StorageService();
      await storage.saveSmokingEvent(
        SmokingEvent(
          id: 'e1',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          source: 'quick_log',
          approximate: false,
        ),
      );

      await tester.pumpWidget(wrap(const HealthRecoveryPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The 20-minute milestone is reached (30 > 20), the 12-hour one is
      // not — exactly one checkmark, not zero and not all of them.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    },
  );

  testWidgets(
    'a long-ago logged cigarette does not overflow the milestone list on a small screen',
    (tester) async {
      final storage = StorageService();
      await storage.saveSmokingEvent(
        SmokingEvent(
          id: 'e1',
          timestamp: DateTime.now().subtract(const Duration(days: 400)),
          source: 'quick_log',
          approximate: false,
        ),
      );

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const HealthRecoveryPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Every milestone in the timeline should now read as reached.
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    },
  );
}
