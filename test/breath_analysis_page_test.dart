import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/breath_progress_record.dart';
import 'package:no_smoke/pages/breath_analysis_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  // Mutable, reassigned once per test in setUp (not recreated per *call*):
  // BreathAnalysisPage and this test file each construct their own separate
  // StorageService() instance, and both call
  // getApplicationDocumentsDirectory() to find the database file — within a
  // single test they must resolve to the same path, or the page will always
  // see an empty database regardless of what the test seeded. But reusing
  // the same directory *across* tests means each test's StorageService
  // instances (this file's and the page's) hold their own open sqflite
  // connections to the same file, and closing only the ones this file knows
  // about still leaves the file locked (Windows can't delete an open file)
  // for the next test's setUp. A fresh directory per test sidesteps that
  // entirely — nothing to delete, so nothing to conflict with a lingering
  // handle.
  static String path = Directory.systemTemp
      .createTempSync('no_smoke_breath_analysis_test')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Pumps the page and waits for its FutureBuilder to resolve. Deliberately
/// not pumpAndSettle(): fl_chart's LineChart/BarChart run their own
/// indefinite internal animations (swapAnimationDuration etc.), which never
/// let pumpAndSettle's "no more frames scheduled" condition become true and
/// hang the test forever.
///
/// A bounded number of `pump(duration)` calls is not enough either: those
/// only advance the fake test clock, they do not wait for real I/O
/// (sqflite_common_ffi's first-open native library load, SharedPreferences
/// plugin round-trips, and — for the records-seeded tests — several prior
/// saveBreathProgressRecord calls) that BreathAnalysisPage's _loadData
/// actually depends on. A single fixed real-time delay isn't reliable
/// either: how long that I/O takes varies with how much has already run
/// (first-open cost, number of seeded records), so this polls in short
/// real-time increments via tester.runAsync until the loading spinner is
/// actually gone, up to a generous ceiling.
Future<void> _pumpAnalysisPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BreathAnalysisPage(),
    ),
  );
  await tester.pump();

  for (var i = 0; i < 40; i++) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    // BreathBadgeService (via BreathAnalysisPage's _loadData) reads/writes
    // SharedPreferences. Without a mock, getInstance() reaches for the real
    // platform channel, which never responds in the test environment — the
    // page's FutureBuilder then never leaves ConnectionState.waiting no
    // matter how many frames are pumped, and the test hangs indefinitely.
    SharedPreferences.setMockInitialValues({});

    // Fresh temp directory per test — see _FakePathProviderPlatform's doc
    // comment for why this replaces closing+deleting a shared file.
    _FakePathProviderPlatform.path = Directory.systemTemp
        .createTempSync('no_smoke_breath_analysis_test')
        .path;
  });

  testWidgets('shows the empty state when there is no breath-test history', (
    tester,
  ) async {
    await _pumpAnalysisPage(tester);

    expect(find.text('Henüz veri yok'), findsOneWidget);
    expect(find.text('Nefes testini başlat'), findsOneWidget);
  });

  testWidgets('shows summary cards, charts, and badges once records exist', (
    tester,
  ) async {
    // Seeding must happen inside runAsync too, for the same reason
    // _pumpAnalysisPage's internal waits do (see its doc comment): these
    // awaits drive real sqflite I/O, which the fake-async zone testWidgets
    // normally runs under does not let complete on its own.
    await tester.runAsync(() async {
      final storageService = StorageService();
      final base = DateTime.now().subtract(const Duration(days: 10));
      for (var i = 0; i < 6; i++) {
        await storageService.saveBreathProgressRecord(
          BreathProgressRecord(
            id: 'r_$i',
            completedAt: base.add(Duration(days: i)),
            breathScore: 40.0 + i * 5,
            blowDurationSeconds: 8,
            blowStability: 0.7,
            blowIntensity: 0.7,
          ),
        );
      }
    });

    await _pumpAnalysisPage(tester);

    // Empty state must not show once there is data.
    expect(find.text('Henüz veri yok'), findsNothing);

    // Summary section headers.
    expect(find.text('İlerleme'), findsOneWidget);
    expect(find.text('En İyi Skor'), findsOneWidget);
    expect(find.text('Tutarlılık'), findsOneWidget);
    expect(find.text('Test Sayısı'), findsOneWidget);

    // Chart card titles.
    expect(find.text('Nefes Skoru — Son 30 Gün'), findsOneWidget);

    // 6 records is under BreathTrendEngine.minimumTestCountForTrend (5)...
    // actually 6 >= 5, so trend should show rather than the not-enough-data
    // notice.
    expect(find.text('Trend için birkaç test daha gerekiyor'), findsNothing);

    // The rest of the cards (weekly bar chart, badges) sit further down the
    // ListView than the default test surface renders without scrolling —
    // scroll down to bring them into the tree before asserting on them.
    await tester.dragUntilVisible(
      find.text('Rozetler'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Haftalık Ortalama'), findsOneWidget);
    expect(find.text('Rozetler'), findsOneWidget);
  });

  testWidgets('shows the not-enough-data notice with fewer than the '
      'minimum test count', (tester) async {
    await tester.runAsync(() async {
      final storageService = StorageService();
      await storageService.saveBreathProgressRecord(
        BreathProgressRecord(
          id: 'r_only',
          completedAt: DateTime.now(),
          breathScore: 50,
          blowDurationSeconds: 8,
          blowStability: 0.7,
          blowIntensity: 0.7,
        ),
      );
    });

    await _pumpAnalysisPage(tester);

    expect(find.text('Trend için birkaç test daha gerekiyor'), findsOneWidget);
  });
}
