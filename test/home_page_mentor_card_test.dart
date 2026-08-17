import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/home_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  static final String _documentsPath = Directory.systemTemp
      .createTempSync('no_smoke_home_mentor_card')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;
}

Widget _wrap() => const MaterialApp(
  locale: Locale('tr'),
  supportedLocales: [Locale('tr'), Locale('en')],
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: HomePage(name: 'Ada', riskScore: 10, riskLevel: 'DUSUK'),
);

// These widget tests exercise the real HomePage mentor-card interaction.
// HomePage performs several sqflite/plugin-backed async reads during startup,
// so pumpUntilMentorCard gives those futures a real async turn before polling
// the rendered card.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const watchdogChannel = MethodChannel('no_smoke/watchdog');
  const stepChannel = MethodChannel('no_smoke/step_tracking');
  const locationChannel = MethodChannel('no_smoke/location_intelligence');
  const smokedLogChannel = MethodChannel('no_smoke/smoked_log_button');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().clearAllData();
    for (final channel in [
      notificationsChannel,
      watchdogChannel,
      stepChannel,
      locationChannel,
      smokedLogChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() async {
    await StorageService().closeDatabaseConnection();
    for (final channel in [
      notificationsChannel,
      watchdogChannel,
      stepChannel,
      locationChannel,
      smokedLogChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  /// Pumps HomePage and waits for the mentor card's async daily-message
  /// load to land, without pumpAndSettle() (this screen has ambient
  /// animations elsewhere that never go idle on their own).
  ///
  /// _ensureMentorMessageCadence only runs once registration reads back as
  /// completed (see HomePage's _loadHomeMetrics), so that's set up first.
  Future<void> pumpUntilMentorCard(WidgetTester tester) async {
    await StorageService().saveInitialRegistrationCompleted(true);
    await tester.pumpWidget(_wrap());
    for (var i = 0; i < 20; i += 1) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 25));
      if (find.widgetWithText(OutlinedButton, 'Zorlanıyorum').evaluate().isNotEmpty ||
          find.widgetWithText(OutlinedButton, 'İyiyim').evaluate().isNotEmpty) {
        break;
      }
    }
  }

  testWidgets(
    'tapping Zorlanıyorum reveals the follow-up question and its 3 buttons',
    (tester) async {
      await pumpUntilMentorCard(tester);

      final strugglingButton = find.widgetWithText(
        OutlinedButton,
        'Zorlanıyorum',
      );
      expect(strugglingButton, findsOneWidget);

      await tester.tap(strugglingButton);
      await tester.pump();

      expect(find.text('Ne tür yardım istersin?'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Görevleri azalt'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Bariyeri gevşet'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Sadece konuşmak istedim'),
        findsOneWidget,
      );
      // The original quick-reply buttons are gone now that we're answered.
      expect(find.widgetWithText(OutlinedButton, 'İyiyim'), findsNothing);
    },
  );

  testWidgets('tapping Görevleri azalt shows the ack text and a SnackBar', (
    tester,
  ) async {
    await pumpUntilMentorCard(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Zorlanıyorum'));
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Görevleri azalt'));
    await tester.pump();

    expect(find.textContaining('görevlerini azalttım'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    // The follow-up buttons are gone now that a choice was made.
    expect(
      find.widgetWithText(OutlinedButton, 'Bariyeri gevşet'),
      findsNothing,
    );
  });

  testWidgets('tapping İyiyim never shows a follow-up question', (
    tester,
  ) async {
    await pumpUntilMentorCard(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'İyiyim'));
    await tester.pump();

    expect(find.text('Ne tür yardım istersin?'), findsNothing);
    // "Yanitin: İyiyim" — the pre-existing "reply sent" acknowledgement,
    // proving the struggling-only follow-up branch was never taken.
    expect(find.textContaining('Yanitin'), findsOneWidget);
  });
}
