import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/home_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_home_bottom_nav').path;
  }
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  tearDown(() {
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

  testWidgets('shows 4 bottom navigation destinations', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Testler'), findsOneWidget);
    expect(find.text('Takip'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });

  testWidgets('tapping a destination switches the visible tab index', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));

    expect(stack().index, 0);

    await tester.tap(find.text('Testler'));
    await tester.pump();
    expect(stack().index, 1);

    await tester.tap(find.text('Takip'));
    await tester.pump();
    expect(stack().index, 2);

    await tester.tap(find.text('Ayarlar'));
    await tester.pump();
    expect(stack().index, 3);
  });

  testWidgets(
    'settings tab renders SettingsPage body without a nested Scaffold',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();

      // Only HomePage's own Scaffold should exist — SettingsPage's body is
      // shown directly inside the IndexedStack, not wrapped in a second one.
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );

  testWidgets('craving SOS button remains visible regardless of selected tab', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.byKey(const ValueKey('craving_sos_button')), findsOneWidget);

    await tester.tap(find.text('Takip'));
    await tester.pump();
    expect(find.byKey(const ValueKey('craving_sos_button')), findsOneWidget);

    await tester.tap(find.text('Ayarlar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('craving_sos_button')), findsOneWidget);
  });
}
