import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/daily_progress_report.dart';
import 'package:no_smoke/models/reduction_progress.dart';
import 'package:no_smoke/models/smoking_count_discrepancy.dart';
import 'package:no_smoke/models/task_assignment.dart';
import 'package:no_smoke/pages/breath_test_page.dart';
import 'package:no_smoke/pages/cough_test_page.dart';
import 'package:no_smoke/pages/sleep_routine_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/widgets/daily_progress_report_view.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_sleep_routine').path;
  }
}

/// The `record` package's method channel — under LiveTestWidgetsFlutterBinding
/// (real wall-clock time, needed to avoid the SQLite-hang documented below)
/// platform channel calls actually round-trip instead of silently resolving
/// some other way, so this needs an explicit mock. `hasPermission` returns
/// false, matching this test environment's "no real mic" reality: every
/// mic-dependent page already falls back to its manual/no-acoustic-reading
/// path when permission is denied, which is the path these tests drive.
const _recordChannel = MethodChannel('com.llfbandit.record/messages');

void _mockRecordChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_recordChannel, (call) async {
        switch (call.method) {
          case 'hasPermission':
            return false;
          case 'isPaused':
          case 'isRecording':
            return false;
          case 'getAmplitude':
            return {'current': 0.0, 'max': 0.0};
          default:
            return null;
        }
      });
}

/// Real StorageService for everything BreathTestPage/CoughTestPage/
/// TaskAssignmentService touch (those already work fine against real
/// sqflite FFI in a widget test — see breath_test_page_test.dart, which
/// only fakes the *blocking, awaited-during-build* calls). Only the two
/// calls SleepRoutinePage itself awaits synchronously during initState/
/// build — evaluateTodaySmokingDiscrepancy and buildDailyProgressReport —
/// are overridden here, because those are awaited directly inside
/// setState-driving code and real FFI I/O awaited that way never resolves
/// inside flutter_test's fake-async pump loop (same root cause documented
/// in notification_kinds_toggle_test.dart's _FakeStorageService).
class _FakeDiscrepancyStorageService extends StorageService {
  _FakeDiscrepancyStorageService({
    required this.discrepancy,
    required this.report,
  });

  final SmokingCountDiscrepancy discrepancy;
  final DailyProgressReport report;
  int recalledHoursCallCount = 0;

  @override
  Future<SmokingCountDiscrepancy> evaluateTodaySmokingDiscrepancy({
    DateTime? now,
  }) async => discrepancy;

  @override
  Future<DailyProgressReport> buildDailyProgressReport({DateTime? now}) async =>
      report;

  @override
  Future<void> logRecalledSmokingHours({
    required DateTime day,
    required List<int> hours,
  }) async {
    recalledHoursCallCount += 1;
  }
}

const _noDiscrepancy = SmokingCountDiscrepancy(
  loggedCount: 20,
  declaredDailyAverage: 20,
  gap: 0,
  hasDiscrepancy: false,
);

const _withDiscrepancy = SmokingCountDiscrepancy(
  loggedCount: 2,
  declaredDailyAverage: 10,
  gap: 8,
  hasDiscrepancy: true,
);

const _emptyReport = DailyProgressReport(
  reductionProgress: ReductionProgress.empty,
  taskSuccessRateLast7Days: 0,
  currentBarrierMinutes: 0,
  lastBreathTestAt: null,
  breathTrend: null,
  todaySmokedCount: 0,
  latestCoughTest: null,
);

/// Under LiveTestWidgetsFlutterBinding, `tester.pump(duration)` does NOT
/// block for `duration` the way it does under the default
/// AutomatedTestWidgetsFlutterBinding's fake clock — its docs say it just
/// "triggers a frame sequence, then flushes microtasks." Real `Timer`s in
/// the widget tree (e.g. BreathTestPage's countdown) run on the real clock
/// regardless, so a loop of instant `pump()` calls races ahead of them. This
/// helper actually waits in real time before each pump, keeping the two
/// clocks in sync.
Future<void> _pumpRealTime(WidgetTester tester, Duration duration) async {
  await Future<void>.delayed(duration);
  await tester.pump();
}

/// Polls in short real-time increments until [finder] actually appears,
/// instead of assuming a fixed number of one-second pumps lines up exactly
/// with a real `Timer`'s firing under LiveTestWidgetsFlutterBinding (small
/// per-call scheduling drift compounds across a 20s rest interval, so a
/// fixed loop can finish a beat early with the target widget not yet
/// rebuilt). Fails via the final `expect` if [timeout] elapses first.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await _pumpRealTime(tester, step);
  }
  expect(
    finder.evaluate().isNotEmpty,
    isTrue,
    reason: 'Timed out waiting for $finder to appear',
  );
}

/// Same polling strategy as [_pumpUntilFound], but succeeds as soon as any
/// one of [finders] appears — for spots where a real Timer's completion can
/// land on one of two different screens (e.g. a result screen, or a retry
/// dialog shown only when the synthetic test data scores zero events).
Future<void> _pumpUntilAnyFound(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 25),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finders.any((finder) => finder.evaluate().isNotEmpty)) {
      return;
    }
    await _pumpRealTime(tester, step);
  }
  expect(
    finders.any((finder) => finder.evaluate().isNotEmpty),
    isTrue,
    reason: 'Timed out waiting for any of $finders to appear',
  );
}

/// Pumps [page] and waits for [SleepRoutinePage]'s initState-driven
/// `_loadSteps` future to resolve, without ever calling `pumpAndSettle()`
/// while its `CircularProgressIndicator` loading state is still on screen —
/// that indicator runs an indefinite animation, so `pumpAndSettle()` would
/// wait for it to go idle forever instead of returning once the steps load.
Future<void> _pumpSleepRoutinePage(WidgetTester tester, Widget page) async {
  // LiveTestWidgetsFlutterBinding's default test surface is 800x600 — too
  // small for SleepRoutinePage's embedded BreathTestPage/CoughTestPage,
  // whose combined header/progress/timer-circle content is taller than
  // that on a real phone too, just scrollable there. Widgets past the
  // 800x600 edge still get real layout positions (tester.tap() computes an
  // Offset from those coordinates), so a tap the framework "resolves" onto
  // the actual widget still fails hit-testing because the point sits
  // outside the test root's render bounds. Note this is setSurfaceSize, not
  // tester.view.physicalSize: LiveTestWidgetsFlutterBinding.
  // createViewConfigurationFor hardcodes `_surfaceSize ?? 800x600` for the
  // implicit view and never reads view.physicalSize, so only the
  // setSurfaceSize path actually changes the root render bounds here.
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1080, 2400));
  addTearDown(() => binding.setSurfaceSize(null));

  await tester.pumpWidget(page);
  // A handful of short pumps is enough to let the awaited (but
  // synchronously-resolving, since it's faked) evaluateTodaySmokingDiscrepancy
  // future complete and the first setState land. Deliberately never
  // pumpAndSettle() here: the loading frame shows an indeterminate
  // CircularProgressIndicator, whose implicit animation never goes idle on
  // its own, so pumpAndSettle() would wait for it forever instead of
  // returning once the steps have actually loaded.
  for (var i = 0; i < 10; i += 1) {
    await _pumpRealTime(tester, const Duration(milliseconds: 50));
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

TaskAssignment _sleepRoutineTask({
  String id = sleepRoutineCanonicalTitle,
  String state = TaskLifecycleState.accepted,
}) {
  return TaskAssignment(
    id: id,
    planDate: '2026-07-20',
    canonicalTitle: sleepRoutineCanonicalTitle,
    durationMinutes: 0,
    scheduledAt: DateTime(2026, 7, 20, 22, 0),
    state: state,
    taskKind: TaskKind.sleepRoutine,
  );
}

/// Drives BreathTestPage's 3-attempt protocol to completion the same way
/// breath_test_page_test.dart does — no real mic in the test environment,
/// so every step is advanced by tapping the timer circle and letting the
/// fixed countdowns elapse. Real (non-fake) BreathTestService is used here
/// since only its final storage write is real I/O, and that write is
/// unawaited (see BreathTestPage._saveBreathProgressRecord), so it never
/// blocks the widget tree the way SleepRoutinePage's own awaited calls do.
/// Dismisses BreathTestPage's one-time mic-permission-rationale dialog if
/// it's up, choosing "Hayır" (don't grant) — the mocked `record` channel
/// already answers `hasPermission: false`, so BreathTestPage falls back to
/// its manual/no-acoustic-reading path regardless of this choice; declining
/// here just keeps the flow from ever calling into the real permission
/// plugin. Under LiveTestWidgetsFlutterBinding's real platform-channel
/// round trips this dialog genuinely appears (unlike under the default
/// binding, where the fake clock let the flow race past it unnoticed) — and
/// since it's shown from an `unawaited()` future in
/// _prepareMicrophoneForAttempt, it can pop up at any point after the first
/// tap, not deterministically before the second. Checked before every tap
/// rather than once.
Future<void> _dismissMicRationaleIfShown(WidgetTester tester) async {
  final noButton = find.text('Hayır');
  if (noButton.evaluate().isNotEmpty) {
    await tester.tap(noButton.first);
    await _pumpRealTime(tester, const Duration(milliseconds: 100));
  }
}

Future<void> _tapTimerCircle(WidgetTester tester, Finder circleFinder) async {
  await _pumpUntilFound(tester, circleFinder);
  await _dismissMicRationaleIfShown(tester);
  await tester.tap(circleFinder);
  await _pumpRealTime(tester, const Duration(milliseconds: 100));
  await _dismissMicRationaleIfShown(tester);
  // ignore: avoid_print
  print(
    '>>> DEBUG after tap: '
    '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((t) => t != null && t.isNotEmpty).toList()}',
  );
}

Future<void> _completeBreathTestStep(WidgetTester tester) async {
  final circleFinder = find.byKey(const ValueKey('breath_timer_circle'));

  // sit-relax -> deep-breath -> holding (this last tap starts the real 3s
  // hold countdown, a genuine Timer.periodic running on the real clock).
  await _tapTimerCircle(tester, circleFinder);
  await _tapTimerCircle(tester, circleFinder);
  await _tapTimerCircle(tester, circleFinder);
  // The hold countdown auto-advances to exhale on its own once it elapses —
  // wait for the circle to come back (it's hidden during the hold step)
  // rather than assuming a fixed number of 1s pumps lines up with the real
  // Timer's third tick.
  await _pumpUntilFound(tester, circleFinder);
  // Finish attempt 1.
  await _tapTimerCircle(tester, circleFinder);

  for (var attempt = 2; attempt <= 3; attempt += 1) {
    // The 20s rest interval auto-starts the next attempt (sit-relax) once
    // it elapses — wait for the circle to reappear rather than pumping a
    // fixed 20 one-second steps, since LiveTestWidgetsFlutterBinding's real
    // clock lets small per-pump scheduling drift compound over 20s.
    await _pumpUntilFound(
      tester,
      circleFinder,
      timeout: const Duration(seconds: 25),
    );
    await _tapTimerCircle(tester, circleFinder); // sit-relax -> deep-breath
    await _tapTimerCircle(tester, circleFinder); // deep-breath -> holding
    await _pumpUntilFound(tester, circleFinder); // hold -> exhale
    await _tapTimerCircle(tester, circleFinder); // finish this attempt
  }
  // Whatever comes next (CoughTestPage, or DailyProgressReportView if the
  // flow skips straight to the report) may itself show a loading spinner
  // while its own storage call resolves — see _pumpSleepRoutinePage's note
  // on why pumpAndSettle() is unsafe here.
  for (var i = 0; i < 10; i += 1) {
    await _pumpRealTime(tester, const Duration(milliseconds: 50));
  }
}

/// Drives CoughTestPage's 30s listen-then-result flow to completion, then
/// taps its "devam" button. No real mic in the test environment: the
/// permission-rationale dialog (asked once) is dismissed with "No", and the
/// engine scores zero coughs from the empty sample list, which is fine —
/// this test is about step sequencing, not the cough count itself.
Future<void> _completeCoughTestStep(WidgetTester tester) async {
  // ignore: avoid_print
  print(
    '>>> DEBUG at _completeCoughTestStep start: '
    'BreathTestPage present=${find.byType(BreathTestPage).evaluate().isNotEmpty}, '
    'CoughTestPage present=${find.byType(CoughTestPage).evaluate().isNotEmpty}, '
    'DailyProgressReportView present='
    '${find.byType(DailyProgressReportView).evaluate().isNotEmpty}, '
    'CircularProgressIndicator present='
    '${find.byType(CircularProgressIndicator).evaluate().isNotEmpty}, '
    'SnackBar present=${find.byType(SnackBar).evaluate().isNotEmpty}, '
    'AlertDialog present=${find.byType(AlertDialog).evaluate().isNotEmpty}',
  );
  // ignore: avoid_print
  print(
    '>>> DEBUG all Text widgets: '
    '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((t) => t != null).take(15).toList()}',
  );
  final elevatedButtonFinder = find.byType(ElevatedButton);
  await _pumpUntilFound(tester, elevatedButtonFinder);
  await tester.tap(elevatedButtonFinder.first);
  await _pumpRealTime(tester, const Duration(milliseconds: 100));

  final noButton = find.text('Hayır');
  if (noButton.evaluate().isNotEmpty) {
    await tester.tap(noButton);
    await _pumpRealTime(tester, const Duration(milliseconds: 100));
  }

  // The 30s listen auto-finishes into _finishTest(). With no real mic
  // samples, analysis.coughCount is always 0, which shows a "cough not
  // detected, retry?" AlertDialog first — it has no ElevatedButton, so wait
  // for either that dialog or the result screen, and dismiss the dialog via
  // its "keep result anyway" TextButton if it's the one that showed up.
  final keepResultButton = find.text('Yine de Devam Et');
  await _pumpUntilAnyFound(tester, [
    elevatedButtonFinder,
    keepResultButton,
  ], timeout: const Duration(seconds: 35));
  if (keepResultButton.evaluate().isNotEmpty) {
    await tester.tap(keepResultButton);
    await _pumpRealTime(tester, const Duration(milliseconds: 100));
    await _pumpUntilFound(tester, elevatedButtonFinder);
  }

  // Result screen's "devam" button. What follows (the discrepancy question
  // or DailyProgressReportView) may itself show a loading spinner.
  await tester.tap(elevatedButtonFinder.first);
  for (var i = 0; i < 10; i += 1) {
    await _pumpRealTime(tester, const Duration(milliseconds: 50));
  }
}

// Previously every test below hung indefinitely on its first pump after
// SleepRoutinePage's initState-driven _loadSteps future resolved. Root
// cause (found 2026-08-12): the default TestWidgetsFlutterBinding runs on
// paused/fake time, which never gets signaled by a real native FFI
// completion callback (sqflite's, arriving on a real OS thread) — so any
// real StorageService I/O followed by a pump/rebuild hangs forever, with no
// exception. LiveTestWidgetsFlutterBinding uses real wall-clock time
// instead and does not hit this. See
// memory/project_widget_test_hang_root_cause.md for the full
// investigation.

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    await StorageService().clearAllData();
    _mockRecordChannel();
  });

  // Deliberately no tearDown() removing the mock handler: AudioRecorder's
  // own dispose() call can still be in flight (fire-and-forget, per
  // BreathTestPage/CoughTestPage's teardown) after the test body returns —
  // under LiveTestWidgetsFlutterBinding's real timing that arrives late
  // enough to race a synchronous tearDown, surfacing as a
  // "MissingPluginException... after the test had completed" failure. The
  // handler is idempotent and re-armed by setUp() before every test anyway.

  testWidgets('cannot be dismissed with the system back gesture', (
    tester,
  ) async {
    final fakeStorage = _FakeDiscrepancyStorageService(
      discrepancy: _noDiscrepancy,
      report: _emptyReport,
    );
    await fakeStorage.saveTaskAssignment(_sleepRoutineTask());

    await _pumpSleepRoutinePage(
      tester,
      _wrap(
        SleepRoutinePage(
          canonicalTitle: sleepRoutineCanonicalTitle,
          name: 'Ada',
          packsPerDay: '1 paket',
          storageService: fakeStorage,
        ),
      ),
    );

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('starts on the breath test step', (tester) async {
    final fakeStorage = _FakeDiscrepancyStorageService(
      discrepancy: _noDiscrepancy,
      report: _emptyReport,
    );
    await fakeStorage.saveTaskAssignment(_sleepRoutineTask());

    await _pumpSleepRoutinePage(
      tester,
      _wrap(
        SleepRoutinePage(
          canonicalTitle: sleepRoutineCanonicalTitle,
          name: 'Ada',
          packsPerDay: '1 paket',
          storageService: fakeStorage,
        ),
      ),
    );

    expect(find.byType(BreathTestPage), findsOneWidget);
  });

  testWidgets(
    'no discrepancy: breath -> cough -> report directly, the discrepancy '
    'question is skipped',
    (tester) async {
      final fakeStorage = _FakeDiscrepancyStorageService(
        discrepancy: _noDiscrepancy,
        report: _emptyReport,
      );
      await fakeStorage.saveTaskAssignment(_sleepRoutineTask());

      await _pumpSleepRoutinePage(
        tester,
        _wrap(
          SleepRoutinePage(
            canonicalTitle: sleepRoutineCanonicalTitle,
            name: 'Ada',
            packsPerDay: '1 paket',
            storageService: fakeStorage,
          ),
        ),
      );

      expect(find.byType(BreathTestPage), findsOneWidget);
      await _completeBreathTestStep(tester);

      await _completeCoughTestStep(tester);

      // Straight to the report — the discrepancy step never appears in
      // between.
      expect(find.byType(DailyProgressReportView), findsOneWidget);
    },
  );

  testWidgets(
    'with a discrepancy: the routine still proceeds directly to the report',
    (tester) async {
      final fakeStorage = _FakeDiscrepancyStorageService(
        discrepancy: _withDiscrepancy,
        report: _emptyReport,
      );
      await fakeStorage.saveTaskAssignment(_sleepRoutineTask());

      await _pumpSleepRoutinePage(
        tester,
        _wrap(
          SleepRoutinePage(
            canonicalTitle: sleepRoutineCanonicalTitle,
            name: 'Ada',
            packsPerDay: '1 paket',
            storageService: fakeStorage,
          ),
        ),
      );

      await _completeBreathTestStep(tester);
      await _completeCoughTestStep(tester);

      // The old smoking-hours discrepancy question was removed from the
      // sleep routine. The daily report is now always the next step.
      expect(find.byType(DailyProgressReportView), findsOneWidget);
      expect(fakeStorage.recalledHoursCallCount, 0);
    },
  );

  testWidgets('closing the report transitions the task to succeeded', (
    tester,
  ) async {
    final fakeStorage = _FakeDiscrepancyStorageService(
      discrepancy: _noDiscrepancy,
      report: _emptyReport,
    );
    await fakeStorage.saveTaskAssignment(_sleepRoutineTask());

    await _pumpSleepRoutinePage(
      tester,
      _wrap(
        SleepRoutinePage(
          canonicalTitle: sleepRoutineCanonicalTitle,
          name: 'Ada',
          packsPerDay: '1 paket',
          storageService: fakeStorage,
        ),
      ),
    );

    await _completeBreathTestStep(tester);
    await _completeCoughTestStep(tester);

    expect(find.byType(DailyProgressReportView), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton).last);
    for (var i = 0; i < 10; i += 1) {
      await _pumpRealTime(tester, const Duration(milliseconds: 50));
    }

    final loaded = await fakeStorage.loadTaskAssignment(
      sleepRoutineCanonicalTitle,
    );
    expect(loaded!.state, TaskLifecycleState.succeeded);
  });
}
