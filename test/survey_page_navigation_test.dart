import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/breath_test_page.dart';
import 'package:no_smoke/pages/risk_result_page.dart';
import 'package:no_smoke/pages/survey_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_widget_test').path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'zonedSchedule') {
        return null;
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('RiskResultPage continues directly to HomePage in initial setup',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RiskResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 8,
          inhaleTestSeconds: 10,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final continueButton = find.byKey(const ValueKey('risk_result_continue_button'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tüm geçmiş anketleri gör'), findsNothing);
    expect(find.text('Ana sayfaya dön'), findsNothing);
  });

  testWidgets('SurveyPage context can push BreathTestPage via Navigator.push',
      (tester) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en')],
        navigatorObservers: [observer],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SurveyPage(),
      ),
    );

    await tester.pumpAndSettle();
    final initialPushCount = observer.pushCount;

    final context = tester.element(find.byType(SurveyPage));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BreathTestPage(
          name: 'Ada',
          packsPerDay: '1 paket',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(observer.pushCount, greaterThan(initialPushCount));
  });

  testWidgets('SurveyPage shows field specific snackbar when validation fails',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SurveyPage(),
      ),
    );

    await tester.pumpAndSettle();

    // SurveyPage's onboarding form is a multi-step SurveyWizard; the
    // primary button reads "İleri" (Next) on every step except the last,
    // where it becomes "Tamamla" (Finish) and triggers the real
    // validation/save flow. Drive through every step to reach it, leaving
    // the (required) name field on step 1 empty the whole way.
    final primaryButton = find.byKey(
      const ValueKey('survey_wizard_primary_button'),
    );
    for (var step = 0; step < 5; step++) {
      await tester.ensureVisible(primaryButton);
      await tester.tap(primaryButton);
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(primaryButton);
    await tester.tap(primaryButton);
    await tester.pump();

    expect(find.text('Lütfen ad alanını doldurun.'), findsOneWidget);
  });
}
