import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/medications_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_medication').path;
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
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // The page shows a spinner while it loads, and a CircularProgressIndicator
  // never stops animating — pumpAndSettle would wait forever. Stepped pumps
  // give the futures room to resolve without needing the tree to go quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets('asks how many times a day before asking for the times', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MedicationsPage()));
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    // How often someone takes something is the thing they actually know; the
    // clock positions follow from it. Previously they added times one by one
    // and the count was only ever implied.
    expect(
      find.byKey(const ValueKey('medication_times_per_day')),
      findsOneWidget,
    );
  });

  testWidgets('suggests a time for each dose, all editable', (tester) async {
    await tester.pumpWidget(wrap(const MedicationsPage()));
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    // Defaults to one dose, so one suggested slot is present immediately —
    // the user never faces an empty list they have to populate themselves.
    expect(find.byKey(const ValueKey('medication_time_0')), findsOneWidget);
  });

  testWidgets('choosing three doses offers three slots', (tester) async {
    await tester.pumpWidget(wrap(const MedicationsPage()));
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('medication_times_per_day')));
    await settle(tester);
    await tester.tap(find.text('3').last);
    await settle(tester);

    expect(find.byKey(const ValueKey('medication_time_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('medication_time_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('medication_time_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('medication_time_3')), findsNothing);
  });
}
