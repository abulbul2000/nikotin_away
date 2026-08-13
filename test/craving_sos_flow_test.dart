import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/craving_sos_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_sos_flow').path;
  }
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  supportedLocales: const [Locale('tr'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

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

  testWidgets('opened without a task, SOS just closes when dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CravingSosPage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // No task to hand back to, so there's nothing to schedule — it simply
    // returns the user where they came from.
    await tester.tap(find.byKey(const ValueKey('sos_dismiss_button')));
    // Stepped rather than pumpAndSettle: the breathing cycle is a repeating
    // timer, so nothing here ever settles.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(CravingSosPage), findsNothing);
  });

  testWidgets(
    'opened from a task, SOS asks when to resume rather than closing',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const CravingSosPage(taskCanonicalTitle: 'ADAPTIVE_NO_SMOKE:30')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('sos_dismiss_button')));
      await tester.pump();

      // The task is suspended, not finished — cancelling it outright would make
      // SOS the cheapest way to never answer one.
      expect(find.byKey(const ValueKey('sos_resume_30')), findsOneWidget);
      expect(find.byKey(const ValueKey('sos_resume_60')), findsOneWidget);
      expect(find.byKey(const ValueKey('sos_resume_120')), findsOneWidget);
    },
  );

  testWidgets('the suggestion step offers something concrete to do', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CravingSosPage(taskCanonicalTitle: 'ADAPTIVE_NO_SMOKE:30')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('sos_suggestion_button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('sos_suggestion_done_button')),
      findsOneWidget,
    );
  });
}
