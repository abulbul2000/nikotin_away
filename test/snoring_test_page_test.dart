import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/snoring_test_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_snoring_test').path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  // Only covers the not-started screen render, deliberately not exercising
  // the mic/countdown flow (no real microphone in the test environment, and
  // this app has a documented history of widget tests near multi-async-step
  // pages hanging unexplained — see home_page_mentor_card_test.dart and
  // sleep_routine_page_test.dart's skip:true comments). The acoustic
  // detection and severity math are fully covered by
  // snoring_acoustic_engine_test.dart instead.
  testWidgets('shows the not-started screen with a start button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SnoringTestPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
  });
}
