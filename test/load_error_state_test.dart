import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/coach_mode_page.dart';
import 'package:no_smoke/pages/health_recovery_page.dart';
import 'package:no_smoke/pages/medications_page.dart';
import 'package:no_smoke/pages/protocol_violations_page.dart';
import 'package:no_smoke/pages/reports_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/widgets/load_error_view.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call while [broken] is false. This
/// is the standard stable-path fixture used across this test suite so a
/// page's own internal StorageService reads back what a test seeds through
/// a separate StorageService instance.
///
/// While [broken] is true, it instead returns a path nested underneath a
/// plain file, which sqlite can never open (ENOTDIR) — a clean, one-shot way
/// to make the *next* database access throw without needing to corrupt or
/// delete a file sqflite_common_ffi's worker isolate may still have a
/// handle open on.
class _SwitchablePathProviderPlatform extends PathProviderPlatform {
  final String _goodPath = Directory.systemTemp
      .createTempSync('no_smoke_load_error_state')
      .path;
  String? _badPath;
  bool broken = false;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (!broken) return _goodPath;
    if (_badPath == null) {
      final blockerDir = Directory.systemTemp.createTempSync(
        'no_smoke_load_error_state_blocker',
      );
      final blockerFile = File('${blockerDir.path}/blocker');
      await blockerFile.writeAsBytes(const [0]);
      _badPath = '${blockerFile.path}/unreachable';
    }
    return _badPath;
  }
}

/// Regression coverage: ReportsPage, ProtocolViolationsPage,
/// HealthRecoveryPage, MedicationsPage and CoachModePage all used to only
/// handle the success path of their initial async load — a thrown exception
/// (corrupt/locked db, I/O failure) left `_loading`/the FutureBuilder stuck
/// on its spinner forever with no way to recover short of leaving and
/// re-entering the page. Every other page with the same shape
/// (achievements_page.dart, savings_page.dart, health_metrics_page.dart,
/// etc.) already catches the error and shows widgets/load_error_view.dart
/// with a retry button; these five didn't.
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  final pathProvider = _SwitchablePathProviderPlatform();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = pathProvider;
  });

  setUp(() async {
    pathProvider.broken = false;
    await StorageService().closeDatabaseConnection();
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

  Future<void> tapRetryInsideLoadErrorView(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(LoadErrorView),
        matching: find.byType(OutlinedButton),
      ),
    );
  }

  testWidgets('ReportsPage shows a retryable error instead of hanging', (
    tester,
  ) async {
    pathProvider.broken = true;
    await StorageService().closeDatabaseConnection();

    await tester.pumpWidget(wrap(const ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsOneWidget);

    pathProvider.broken = false;
    await StorageService().closeDatabaseConnection();
    await tapRetryInsideLoadErrorView(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsNothing);
  });

  testWidgets(
    'ProtocolViolationsPage shows a retryable error instead of hanging',
    (tester) async {
      pathProvider.broken = true;
      await StorageService().closeDatabaseConnection();

      await tester.pumpWidget(wrap(const ProtocolViolationsPage()));
      await tester.pumpAndSettle();

      expect(find.byType(LoadErrorView), findsOneWidget);

      pathProvider.broken = false;
      await StorageService().closeDatabaseConnection();
      await tapRetryInsideLoadErrorView(tester);
      await tester.pumpAndSettle();

      expect(find.byType(LoadErrorView), findsNothing);
    },
  );

  testWidgets('HealthRecoveryPage shows a retryable error instead of hanging', (
    tester,
  ) async {
    pathProvider.broken = true;
    await StorageService().closeDatabaseConnection();

    await tester.pumpWidget(wrap(const HealthRecoveryPage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsOneWidget);

    pathProvider.broken = false;
    await StorageService().closeDatabaseConnection();
    await tapRetryInsideLoadErrorView(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsNothing);
  });

  testWidgets('MedicationsPage shows a retryable error instead of hanging', (
    tester,
  ) async {
    pathProvider.broken = true;
    await StorageService().closeDatabaseConnection();

    await tester.pumpWidget(wrap(const MedicationsPage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsOneWidget);

    pathProvider.broken = false;
    await StorageService().closeDatabaseConnection();
    await tapRetryInsideLoadErrorView(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsNothing);
  });

  testWidgets('CoachModePage shows a retryable error instead of hanging', (
    tester,
  ) async {
    pathProvider.broken = true;
    await StorageService().closeDatabaseConnection();

    await tester.pumpWidget(wrap(const CoachModePage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsOneWidget);

    pathProvider.broken = false;
    await StorageService().closeDatabaseConnection();
    await tapRetryInsideLoadErrorView(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoadErrorView), findsNothing);
  });
}
