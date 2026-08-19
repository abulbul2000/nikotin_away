import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/task_assignment.dart';
import 'package:no_smoke/pages/craving_sos_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Returns the same directory on every call — needed so this test's own
/// StorageService instance and CravingSosPage's internal one land in the
/// same sqlite file.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_sos_flow')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
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

// LiveTestWidgetsFlutterBinding, not the default TestWidgetsFlutterBinding:
// _handleDismiss now awaits a real sqflite FFI round trip
// (_activeTaskResolved) before setState, and the default binding's fake
// clock never lets that native I/O actually resolve under a plain pump() —
// pumpAndSettle()/pump() would just hang or return before the state
// change landed (same root cause documented in
// sleep_routine_page_test.dart/health_metrics_page_test.dart).
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await StorageService().clearAllData();
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
      // _handleDismiss now awaits _resolveActiveTask's own database round
      // trip before setState -- give it real wall-clock time to resolve
      // under LiveTestWidgetsFlutterBinding rather than a zero-duration pump.
      await tester.pump(const Duration(milliseconds: 300));

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

  testWidgets(
    'a barrier-running task is still routed to the resumed (not resume-choice) screen even when dismissed before the lookup settles',
    (tester) async {
      // Regression coverage: _resolveActiveTask (which both determines
      // _wasBarrierRunning and suspends the task into sosActive) used to
      // run fully unguarded against the Dismiss button, which is tappable
      // from the very first frame. Dismissing before that lookup finished
      // meant _wasBarrierRunning was still its false default, routing an
      // actually-running barrier to the postpone-choice screen instead of
      // the resume-accepted screen — and, worse, _resumeTaskIn's own
      // postponed write could land before _resolveActiveTask's sosActive
      // write, so the sosActive write landing last would silently revert
      // the task the user just told the app to postpone.
      final storage = StorageService();
      await storage.saveTaskAssignment(
        TaskAssignment(
          id: 'sos_race_task',
          planDate: '2026-01-01',
          canonicalTitle: 'ADAPTIVE_NO_SMOKE:30',
          durationMinutes: 30,
          scheduledAt: DateTime(2026, 1, 1, 9, 0),
          state: TaskLifecycleState.accepted,
        ),
      );

      await tester.pumpWidget(
        _wrap(const CravingSosPage(taskCanonicalTitle: 'ADAPTIVE_NO_SMOKE:30')),
      );
      // No settling pump at all -- Dismiss is tapped on the very first
      // frame, before _resolveActiveTask's database round trip has any
      // realistic chance to have completed.
      await tester.tap(find.byKey(const ValueKey('sos_dismiss_button')));
      // _handleDismiss now waits on the same _activeTaskResolved future
      // _resolveActiveTask kicked off in initState, so it doesn't matter
      // that Dismiss was tapped immediately -- give it real wall-clock
      // time to actually resolve under LiveTestWidgetsFlutterBinding.
      await tester.pump(const Duration(milliseconds: 300));

      // The barrier was running, so this must land on the "resumed"
      // screen (a single "keep going" continuation), never the
      // postpone-choice screen a fresh, not-yet-running task would get.
      expect(find.byKey(const ValueKey('sos_resume_30')), findsNothing);
      expect(find.byKey(const ValueKey('sos_resume_60')), findsNothing);
      expect(find.byKey(const ValueKey('sos_resume_120')), findsNothing);
      expect(
        find.byKey(const ValueKey('sos_barrier_resumed_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('sos_barrier_resumed_button')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final loaded = await storage.loadTaskAssignment('sos_race_task');
      // Back to accepted (sosActive was suspended and then resumed) --
      // never left dangling in sosActive, and never silently reverted to
      // sosActive by a write that raced the resolve landing after this one.
      expect(loaded!.state, TaskLifecycleState.accepted);
    },
  );
}
