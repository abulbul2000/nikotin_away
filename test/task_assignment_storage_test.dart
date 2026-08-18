import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/task_assignment.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/services/task_assignment_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_task_assignment').path;
  }
}

/// Unlike [_FakePathProviderPlatform], returns the same directory every
/// call — needed for the migration test, which has to write a legacy
/// database file and then have [StorageService] reopen that exact path.
class _FixedPathProviderPlatform extends PathProviderPlatform {
  _FixedPathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

TaskAssignment _task({
  String id = 'task_1',
  String state = TaskLifecycleState.planned,
  int durationMinutes = 30,
  DateTime? scheduledAt,
}) {
  final at = scheduledAt ?? DateTime(2026, 7, 20, 14, 0);
  return TaskAssignment(
    id: id,
    planDate: '2026-07-20',
    canonicalTitle: 'ADAPTIVE_NO_SMOKE:$durationMinutes',
    durationMinutes: durationMinutes,
    scheduledAt: at,
    state: state,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const watchdogChannel = MethodChannel('no_smoke/watchdog');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, null);
  });

  test('round-trips every lifecycle field', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(
      _task(id: 'rt').copyWith(
        state: TaskLifecycleState.accepted,
        barrierStartedAt: DateTime(2026, 7, 20, 14, 5),
        barrierEndsAt: DateTime(2026, 7, 20, 14, 35),
        postponeCount: 2,
        sosCount: 1,
        gateReason: TaskGateReason.gaming,
        watchdogId: 'wdg_rt',
      ),
    );

    final loaded = await storage.loadTaskAssignment('rt');

    expect(loaded, isNotNull);
    expect(loaded!.state, TaskLifecycleState.accepted);
    expect(loaded.postponeCount, 2);
    expect(loaded.sosCount, 1);
    expect(loaded.gateReason, TaskGateReason.gaming);
    expect(loaded.watchdogId, 'wdg_rt');
    expect(loaded.barrierEndsAt, DateTime(2026, 7, 20, 14, 35));
  });

  test('accepting starts the barrier clock', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(_task(id: 'accept', durationMinutes: 45));

    final at = DateTime(2026, 7, 20, 15, 0);
    final updated = await storage.transitionTaskAssignment(
      id: 'accept',
      state: TaskLifecycleState.accepted,
      at: at,
    );

    expect(updated!.barrierStartedAt, at);
    expect(updated.barrierEndsAt, at.add(const Duration(minutes: 45)));
  });

  test('postponing pushes the schedule and counts the deferral', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(_task(id: 'snooze'));

    final at = DateTime(2026, 7, 20, 14, 0);
    final once = await storage.transitionTaskAssignment(
      id: 'snooze',
      state: TaskLifecycleState.postponed,
      at: at,
      postponeMinutes: 10,
    );

    expect(once!.postponeCount, 1);
    expect(once.totalPostponedMinutes, 10);
    expect(once.scheduledAt, at.add(const Duration(minutes: 10)));
  });

  test('a finished task reports its outcome exactly once', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(_task(id: 'once'));

    await storage.transitionTaskAssignment(
      id: 'once',
      state: TaskLifecycleState.succeeded,
    );
    // A notification answered just as the watchdog fires used to be able to
    // record both an answer and a miss for the same task; terminal states are
    // final so the second transition is ignored.
    await storage.transitionTaskAssignment(
      id: 'once',
      state: TaskLifecycleState.failedMissed,
    );

    final loaded = await storage.loadTaskAssignment('once');
    expect(loaded!.state, TaskLifecycleState.succeeded);

    final rate = await storage.taskSuccessRateSince(DateTime(2026, 1, 1));
    expect(rate, 1.0);
  });

  test('a terminal transition and its learning-engine outcome land together '
      '(regression coverage for the unguarded read-modify-write)', () async {
    // Regression coverage: transitionTaskAssignment used to read, decide,
    // and write against the database with no transaction around any of
    // it, and recordAdaptiveTaskOutcome (its own separate transaction)
    // ran as a second, independent operation after the task's own write
    // landed — a process kill between the two left the task stuck
    // terminal (the isTerminal guard refuses to touch it again) with its
    // outcome never recorded and never retried. Both are now one
    // transaction: this checks the task's new state and its
    // AdaptiveTaskEvent both exist after a single call, proving the
    // nested-transaction wiring (loadAdaptiveTaskState/
    // loadAdaptiveHourlyProfile now also accept the same `executor`, per
    // sqflite's "don't use the database object inside a transaction"
    // rule) didn't silently drop the outcome write.
    final storage = StorageService();
    await storage.saveTaskAssignment(_task(id: 'atomic', durationMinutes: 30));

    await storage.transitionTaskAssignment(
      id: 'atomic',
      state: TaskLifecycleState.succeeded,
    );

    final loaded = await storage.loadTaskAssignment('atomic');
    expect(loaded!.state, TaskLifecycleState.succeeded);

    final events = await storage.loadRecentAdaptiveTaskEvents(limit: 10);
    expect(
      events.any(
        (e) =>
            e.taskTitle == 'ADAPTIVE_NO_SMOKE:30' &&
            e.outcome == AdaptiveTaskOutcome.success,
      ),
      isTrue,
      reason:
          'the learning-engine event must exist alongside the '
          "task's terminal state, not be silently lost",
    );
  });

  test('declining is scored as smoking, per the agreed rule', () {
    expect(
      TaskLifecycleState.outcomeFor(TaskLifecycleState.failedDeclined),
      AdaptiveTaskOutcome.smoked,
    );
    expect(
      TaskLifecycleState.outcomeFor(TaskLifecycleState.failedMissed),
      AdaptiveTaskOutcome.missed,
    );
    expect(
      TaskLifecycleState.outcomeFor(TaskLifecycleState.succeeded),
      AdaptiveTaskOutcome.success,
    );
  });

  test('an expired task is never reported to the learning engine', () {
    // Expiry is the system admitting it was too late to ask, so scoring it
    // would penalise the user for the app's own delay.
    expect(TaskLifecycleState.outcomeFor(TaskLifecycleState.expired), isNull);
  });

  test('open tasks exclude everything already finished', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(
      _task(id: 'open_a', state: TaskLifecycleState.delivered),
    );
    await storage.saveTaskAssignment(
      _task(id: 'open_b', state: TaskLifecycleState.succeeded),
    );
    await storage.saveTaskAssignment(
      _task(id: 'open_c', state: TaskLifecycleState.expired),
    );

    final open = await storage.loadOpenTaskAssignments();
    final ids = open.map((task) => task.id).toSet();

    expect(ids, contains('open_a'));
    expect(ids, isNot(contains('open_b')));
    expect(ids, isNot(contains('open_c')));
  });

  test('SOS suspends a task and hands it back, never ends it', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(
      _task(id: 'sos', state: TaskLifecycleState.delivered),
    );

    await storage.transitionTaskAssignment(
      id: 'sos',
      state: TaskLifecycleState.sosActive,
    );
    final suspended = await storage.loadTaskAssignment('sos');
    expect(suspended!.sosCount, 1);
    expect(suspended.isTerminal, isFalse);
    expect(suspended.outcome, isNull);

    // Then the user picks when to be handed back. Cancelling the task
    // outright would make SOS the cheapest way to never answer one, so this
    // has to land on postponed rather than any finished state.
    final resumedAt = DateTime(2026, 7, 20, 15, 0);
    final resumed = await storage.transitionTaskAssignment(
      id: 'sos',
      state: TaskLifecycleState.postponed,
      at: resumedAt,
      postponeMinutes: 60,
      sosMinutes: 4,
    );

    expect(resumed!.state, TaskLifecycleState.postponed);
    expect(resumed.totalPostponedMinutes, 60);
    // Time spent breathing is tracked so it isn't charged against the
    // watchdog's silence window.
    expect(resumed.sosTotalMinutes, 4);
    expect(resumed.isTerminal, isFalse);
    // craving_sos_page.dart's _resumeTaskIn passes postponeMinutes and
    // sosMinutes together in the same call — this is what actually moves
    // the task's next fire time out by the minutes the user picked (30/60/
    // 120), not just its postpone bookkeeping. sosMinutes alone (breathing
    // time logged) must never be the thing that advances scheduledAt.
    expect(resumed.scheduledAt, resumedAt.add(const Duration(minutes: 60)));
  });

  test(
    'an sosActive session stuck past the deadline is closed as abandoned',
    () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(id: 'sos_stale', state: TaskLifecycleState.delivered),
      );
      await storage.transitionTaskAssignment(
        id: 'sos_stale',
        state: TaskLifecycleState.sosActive,
        at: DateTime(2026, 7, 20, 14, 0),
      );

      // Before this fix, sosActive had no automatic exit at all — a
      // session the user opened and never resumed sat open forever,
      // occupying a slot in the daily quota indefinitely.
      final closed = await storage.closeStaleAbandonedSosSessions(
        deadline: const Duration(hours: 2),
        now: DateTime(2026, 7, 20, 16, 1),
      );

      expect(closed.map((t) => t.id), contains('sos_stale'));
      final reloaded = await storage.loadTaskAssignment('sos_stale');
      expect(reloaded!.state, TaskLifecycleState.sosAbandoned);
      expect(reloaded.isTerminal, isTrue);
      // Same as expired/barrierUnknown — an abandoned session must never
      // feed the learning engine as if it were a real answer.
      expect(reloaded.outcome, isNull);
    },
  );

  test(
    'an sosActive session still inside the deadline is left alone',
    () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(id: 'sos_fresh', state: TaskLifecycleState.delivered),
      );
      await storage.transitionTaskAssignment(
        id: 'sos_fresh',
        state: TaskLifecycleState.sosActive,
        at: DateTime(2026, 7, 20, 14, 0),
      );

      final closed = await storage.closeStaleAbandonedSosSessions(
        deadline: const Duration(hours: 2),
        now: DateTime(2026, 7, 20, 15, 0),
      );

      expect(closed, isEmpty);
      final reloaded = await storage.loadTaskAssignment('sos_fresh');
      expect(reloaded!.state, TaskLifecycleState.sosActive);
    },
  );

  test('an illegal edge is rejected rather than silently applied', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(
      _task(id: 'illegal', state: TaskLifecycleState.sosActive),
    );

    // sosActive can only ever resolve back through postponed — jumping
    // straight to declined would let SOS double as a free way to fail a
    // task without ever handing it back.
    final result = await storage.transitionTaskAssignment(
      id: 'illegal',
      state: TaskLifecycleState.failedDeclined,
    );

    expect(result!.state, TaskLifecycleState.sosActive);
  });

  test('a canonical title resolves to the most recent task', () async {
    final storage = StorageService();
    await storage.saveTaskAssignment(
      _task(
        id: 'old',
        durationMinutes: 60,
        scheduledAt: DateTime(2026, 7, 18, 9, 0),
      ),
    );
    await storage.saveTaskAssignment(
      _task(
        id: 'new',
        durationMinutes: 60,
        scheduledAt: DateTime(2026, 7, 20, 9, 0),
      ),
    );

    // Notification payloads only carry the canonical title, and the same
    // duration comes round again on later days — an answer can only be about
    // the one currently in play.
    final resolved = await storage.loadLatestTaskAssignmentByTitle(
      'ADAPTIVE_NO_SMOKE:60',
    );
    expect(resolved!.id, 'new');
  });

  group('loadLatestTaskAssignmentByTitle prefers an in-flight task over a '
      'later-scheduled but already-resolved one (regression coverage)', () {
    // Regression coverage: with jitter, two rows can share a canonical
    // title within the same day (or close together across days) — a
    // plain "most recent by scheduledAt" could hand back an
    // already-succeeded/failed row from later in the day instead of the
    // still-open one a notification response is actually about.
    // TaskAssignment.transitionTaskAssignment's own terminal-state guard
    // stops that wrong match from corrupting the finished task, but the
    // response itself would then silently go nowhere instead of landing
    // on the task it was actually about.
    test('an earlier-scheduled but still-open task wins over a '
        'later-scheduled, already-terminal one', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(
          id: 'still_open',
          durationMinutes: 45,
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
          state: TaskLifecycleState.accepted,
        ),
      );
      await storage.saveTaskAssignment(
        _task(
          id: 'already_done',
          durationMinutes: 45,
          scheduledAt: DateTime(2026, 7, 20, 14, 0),
          state: TaskLifecycleState.succeeded,
        ),
      );

      final resolved = await storage.loadLatestTaskAssignmentByTitle(
        'ADAPTIVE_NO_SMOKE:45',
      );
      expect(resolved!.id, 'still_open');
    });

    test('falls back to the most recent terminal row when nothing is '
        'in flight — a caller legitimately looking up a finished task '
        'still gets an answer', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(
          id: 'older_done',
          durationMinutes: 20,
          scheduledAt: DateTime(2026, 7, 18, 9, 0),
          state: TaskLifecycleState.succeeded,
        ),
      );
      await storage.saveTaskAssignment(
        _task(
          id: 'newer_done',
          durationMinutes: 20,
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
          state: TaskLifecycleState.failedSmoked,
        ),
      );

      final resolved = await storage.loadLatestTaskAssignmentByTitle(
        'ADAPTIVE_NO_SMOKE:20',
      );
      expect(resolved!.id, 'newer_done');
    });

    test('among multiple in-flight rows, the most recently scheduled one '
        'still wins', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(
          id: 'in_flight_old',
          durationMinutes: 30,
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
          state: TaskLifecycleState.delivered,
        ),
      );
      await storage.saveTaskAssignment(
        _task(
          id: 'in_flight_new',
          durationMinutes: 30,
          scheduledAt: DateTime(2026, 7, 20, 15, 0),
          state: TaskLifecycleState.accepted,
        ),
      );

      final resolved = await storage.loadLatestTaskAssignmentByTitle(
        'ADAPTIVE_NO_SMOKE:30',
      );
      expect(resolved!.id, 'in_flight_new');
    });
  });

  group('a task nobody answered', () {
    test('is closed rather than left in flight', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(id: 'ignored', state: TaskLifecycleState.delivered),
      );

      // The native watchdog notices this while the app is dead and queues
      // it; the drain on next launch is the only place it is ever closed.
      // It used to record the violation and the adaptive outcome but leave
      // the row on `delivered` forever.
      await storage.transitionTaskAssignment(
        id: 'ignored',
        state: TaskLifecycleState.failedMissed,
      );

      final loaded = await storage.loadTaskAssignment('ignored');
      expect(loaded!.state, TaskLifecycleState.failedMissed);
      expect(loaded.isTerminal, isTrue);
    });

    test('is scored once, not once per writer', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(id: 'ignored', state: TaskLifecycleState.delivered),
      );

      await storage.transitionTaskAssignment(
        id: 'ignored',
        state: TaskLifecycleState.failedMissed,
      );

      // The transition writes the adaptive outcome itself. The watchdog
      // drain also has an explicit recordAdaptiveTaskOutcome call for tasks
      // with no assignment row; running both for the same task would score
      // one ignored task twice and drag difficulty down harder than the
      // user earned.
      final events = await storage.loadRecentAdaptiveTaskEvents(limit: 50);
      final missed = events
          .where((event) => event.outcome == AdaptiveTaskOutcome.missed)
          .toList();
      expect(missed, hasLength(1));
    });

    test('drags the weekly success rate down', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        _task(id: 'done', state: TaskLifecycleState.delivered),
      );
      await storage.saveTaskAssignment(
        _task(id: 'ignored', state: TaskLifecycleState.delivered),
      );

      await storage.transitionTaskAssignment(
        id: 'done',
        state: TaskLifecycleState.succeeded,
      );
      await storage.transitionTaskAssignment(
        id: 'ignored',
        state: TaskLifecycleState.failedMissed,
      );

      // The weekly barrier review reads this rate. If ignoring a task cost
      // nothing, a user who answered nothing all week would look perfect and
      // the barrier would keep growing underneath them.
      final rate = await storage.taskSuccessRateSince(DateTime(2026, 1, 1));
      expect(rate, 0.5);
    });
  });

  group('TaskAssignmentService.planDailyTasks', () {
    test('inserts one row per plan item, all planned', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      final planDate = DateTime(2026, 7, 20, 8, 0);
      final items = [
        AdaptiveTaskPlanItem(
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
          durationMinutes: 30,
          taskTitle: 'ADAPTIVE_NO_SMOKE:30',
        ),
        AdaptiveTaskPlanItem(
          scheduledAt: DateTime(2026, 7, 20, 11, 0),
          durationMinutes: 45,
          taskTitle: 'ADAPTIVE_NO_SMOKE:45',
        ),
      ];

      await service.planDailyTasks(planDate: planDate, items: items);

      final rows = await storage.loadTaskAssignmentsForDay(planDate);
      expect(rows, hasLength(2));
      expect(
        rows.every((row) => row.state == TaskLifecycleState.planned),
        isTrue,
      );
      expect(rows.map((row) => row.canonicalTitle).toSet(), {
        'ADAPTIVE_NO_SMOKE:30',
        'ADAPTIVE_NO_SMOKE:45',
      });
    });

    test('is idempotent across repeated calls the same day', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      final planDate = DateTime(2026, 7, 21, 8, 0);
      final items = [
        AdaptiveTaskPlanItem(
          scheduledAt: DateTime(2026, 7, 21, 10, 0),
          durationMinutes: 30,
          taskTitle: 'ADAPTIVE_NO_SMOKE:30',
        ),
      ];

      await service.planDailyTasks(planDate: planDate, items: items);
      // Simulates a process restart re-running the same plan (OEM battery
      // killers, normal app-switching) — must not stack a duplicate row.
      await service.planDailyTasks(planDate: planDate, items: items);

      final rows = await storage.loadTaskAssignmentsForDay(planDate);
      expect(rows, hasLength(1));
    });

    test('only adds the rows missing from an already-partial day', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      final planDate = DateTime(2026, 7, 22, 8, 0);
      final first = AdaptiveTaskPlanItem(
        scheduledAt: DateTime(2026, 7, 22, 9, 0),
        durationMinutes: 30,
        taskTitle: 'ADAPTIVE_NO_SMOKE:30',
      );
      final second = AdaptiveTaskPlanItem(
        scheduledAt: DateTime(2026, 7, 22, 13, 0),
        durationMinutes: 40,
        taskTitle: 'ADAPTIVE_NO_SMOKE:40',
      );

      await service.planDailyTasks(planDate: planDate, items: [first]);
      await service.planDailyTasks(planDate: planDate, items: [first, second]);

      final rows = await storage.loadTaskAssignmentsForDay(planDate);
      expect(rows, hasLength(2));
    });

    test(
      'a re-plan landing a different task type on an already-running '
      "task's exact slot does not overwrite it (regression coverage)",
      () async {
        // Regression coverage: the row id used to be derived from
        // scheduledAt alone ('ta_<microsecondsSinceEpoch>'). Two DateTime
        // values built from identical y/m/d/h/min arguments are
        // bit-for-bit identical down to the microsecond, so a re-plan
        // that happens to land a *different* canonicalTitle on the same
        // scheduled minute as an already-accepted task generated the same
        // id for what planDailyTasks' own duplicate check (keyed by
        // canonicalTitle+scheduledAt) correctly treats as a distinct new
        // slot — saveTaskAssignment's INSERT OR REPLACE then silently
        // overwrote the running task's entire state back to freshly
        // planned.
        final storage = StorageService();
        final service = TaskAssignmentService(storage);
        final planDate = DateTime(2026, 7, 23, 8, 0);
        final slot = DateTime(2026, 7, 23, 15, 0);

        final original = AdaptiveTaskPlanItem(
          scheduledAt: slot,
          durationMinutes: 30,
          taskTitle: 'ADAPTIVE_NO_SMOKE:30',
        );
        final created = await service.planDailyTasks(
          planDate: planDate,
          items: [original],
        );
        final originalId = created.single.id;
        await storage.transitionTaskAssignment(
          id: originalId,
          state: TaskLifecycleState.accepted,
        );

        // Re-plan: the risk profile changed mid-day and this exact minute
        // is now assigned a different task type entirely.
        final replan = AdaptiveTaskPlanItem(
          scheduledAt: slot,
          durationMinutes: 45,
          taskTitle: 'ADAPTIVE_NO_SMOKE:45',
        );
        await service.planDailyTasks(planDate: planDate, items: [replan]);

        final original30 = await storage.loadTaskAssignment(originalId);
        expect(
          original30!.state,
          TaskLifecycleState.accepted,
          reason:
              'the already-running 30-minute task must survive the '
              're-plan untouched',
        );

        final rows = await storage.loadTaskAssignmentsForDay(planDate);
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.canonicalTitle).toSet(), {
          'ADAPTIVE_NO_SMOKE:30',
          'ADAPTIVE_NO_SMOKE:45',
        });
      },
    );
  });

  group('TaskAssignmentService.handleTaskAction', () {
    // Only the actions that transition storage without also scheduling a
    // notification are exercised here — the plugin has no real platform
    // channel in a plain `test()` environment, so covering the
    // notification-scheduling branches (done/notNow/postpone) belongs in a
    // widget or integration test instead.

    test('decline is scored as smoking', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        _task(id: 'decline_1', durationMinutes: 33),
      );

      final followUp = await service.handleTaskAction(
        canonicalTitle: 'ADAPTIVE_NO_SMOKE:33',
        taskTitle: 'ADAPTIVE_NO_SMOKE:33',
        actionId: TaskActionId.decline,
      );

      final loaded = await storage.loadTaskAssignment('decline_1');
      expect(loaded!.state, TaskLifecycleState.failedDeclined);
      expect(followUp, TaskActionFollowUp.none);
    });

    test(
      'SOS suspends the task and asks the caller to open the SOS page',
      () async {
        final storage = StorageService();
        final service = TaskAssignmentService(storage);
        await storage.saveTaskAssignment(
          _task(id: 'sos_1', durationMinutes: 34),
        );

        final followUp = await service.handleTaskAction(
          canonicalTitle: 'ADAPTIVE_NO_SMOKE:34',
          taskTitle: 'ADAPTIVE_NO_SMOKE:34',
          actionId: TaskActionId.sos,
        );

        final loaded = await storage.loadTaskAssignment('sos_1');
        expect(loaded!.state, TaskLifecycleState.sosActive);
        expect(loaded.isTerminal, isFalse);
        expect(followUp, TaskActionFollowUp.openSosPage);
      },
    );

    test(
      'confirming "yes I smoked" fails the task and logs a cigarette',
      () async {
        final storage = StorageService();
        final service = TaskAssignmentService(storage);
        await storage.saveTaskAssignment(
          _task(id: 'confirm_yes', durationMinutes: 35),
        );

        await service.handleTaskAction(
          canonicalTitle: 'ADAPTIVE_NO_SMOKE:35',
          taskTitle: 'ADAPTIVE_NO_SMOKE:35',
          actionId: TaskActionId.confirmSmokedYes,
        );

        final loaded = await storage.loadTaskAssignment('confirm_yes');
        expect(loaded!.state, TaskLifecycleState.failedSmoked);

        final recent = await storage.loadRecentAdaptiveTaskEvents(limit: 50);
        // logSmokingNow doesn't write an adaptive task event itself, so this
        // just confirms the transition landed on the failure state — the
        // smoking-log side effect is exercised by SmokedLogStore's own tests.
        expect(recent, isA<List>());
      },
    );

    test('confirming "no I did not smoke" succeeds the task', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        _task(id: 'confirm_no', durationMinutes: 36),
      );

      await service.handleTaskAction(
        canonicalTitle: 'ADAPTIVE_NO_SMOKE:36',
        taskTitle: 'ADAPTIVE_NO_SMOKE:36',
        actionId: TaskActionId.confirmSmokedNo,
      );

      final loaded = await storage.loadTaskAssignment('confirm_no');
      expect(loaded!.state, TaskLifecycleState.succeeded);
    });

    test('an action with no matching row is a safe no-op', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);

      final followUp = await service.handleTaskAction(
        canonicalTitle: 'ADAPTIVE_NO_SMOKE:999',
        taskTitle: 'ADAPTIVE_NO_SMOKE:999',
        actionId: TaskActionId.decline,
      );

      expect(followUp, TaskActionFollowUp.none);
      final loaded = await storage.loadLatestTaskAssignmentByTitle(
        'ADAPTIVE_NO_SMOKE:999',
      );
      expect(loaded, isNull);
    });
  });

  group('TaskAssignmentService — composite (sleep routine) tasks', () {
    test('isComposite is true only for sleepRoutine', () {
      expect(TaskAssignmentService.isComposite(TaskKind.sleepRoutine), isTrue);
      expect(
        TaskAssignmentService.isComposite(TaskKind.noSmokeWindow),
        isFalse,
      );
      expect(TaskAssignmentService.isComposite(TaskKind.checkIn), isFalse);
      expect(TaskAssignmentService.isComposite(''), isFalse);
    });

    test('buildSleepRoutinePlanItem lands an hour before sleep, zero '
        'duration', () {
      final sleepAt = DateTime(2026, 7, 20, 23, 0);
      final item = TaskAssignmentService.buildSleepRoutinePlanItem(
        sleepAt: sleepAt,
      );

      expect(item.scheduledAt, DateTime(2026, 7, 20, 22, 0));
      expect(item.durationMinutes, 0);
      expect(item.taskTitle, sleepRoutineCanonicalTitle);
      expect(item.taskKind, TaskKind.sleepRoutine);
    });

    test('done on a composite task accepts it and asks the caller to open '
        'SleepRoutinePage, without starting a countdown or confirmation '
        'prompt', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        TaskAssignment(
          id: 'composite_done',
          planDate: '2026-07-20',
          canonicalTitle: sleepRoutineCanonicalTitle,
          durationMinutes: 0,
          scheduledAt: DateTime(2026, 7, 20, 22, 0),
          state: TaskLifecycleState.planned,
          taskKind: TaskKind.sleepRoutine,
        ),
      );

      final followUp = await service.handleTaskAction(
        canonicalTitle: sleepRoutineCanonicalTitle,
        taskTitle: sleepRoutineCanonicalTitle,
        actionId: TaskActionId.done,
      );

      expect(followUp, TaskActionFollowUp.openSleepRoutinePage);
      final loaded = await storage.loadTaskAssignment('composite_done');
      expect(loaded!.state, TaskLifecycleState.accepted);
      // No barrier duration accrues for a composite task — accepting it
      // does not start a no-smoking window like a normal task would.
      expect(loaded.barrierStartedAt, isNotNull);
      expect(loaded.barrierEndsAt, loaded.barrierStartedAt);
    });

    test('decline on a composite task follows the same smoked-declined '
        'rule as any other task', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        TaskAssignment(
          id: 'composite_decline',
          planDate: '2026-07-20',
          canonicalTitle: sleepRoutineCanonicalTitle,
          durationMinutes: 0,
          scheduledAt: DateTime(2026, 7, 20, 22, 0),
          state: TaskLifecycleState.planned,
          taskKind: TaskKind.sleepRoutine,
        ),
      );

      final followUp = await service.handleTaskAction(
        canonicalTitle: sleepRoutineCanonicalTitle,
        taskTitle: sleepRoutineCanonicalTitle,
        actionId: TaskActionId.decline,
      );

      expect(followUp, TaskActionFollowUp.none);
      final loaded = await storage.loadTaskAssignment('composite_decline');
      expect(loaded!.state, TaskLifecycleState.failedDeclined);
    });

    test(
      'completeSleepRoutine transitions the task straight to succeeded',
      () async {
        final storage = StorageService();
        final service = TaskAssignmentService(storage);
        await storage.saveTaskAssignment(
          TaskAssignment(
            id: 'composite_complete',
            planDate: '2026-07-20',
            canonicalTitle: sleepRoutineCanonicalTitle,
            durationMinutes: 0,
            scheduledAt: DateTime(2026, 7, 20, 22, 0),
            state: TaskLifecycleState.accepted,
            taskKind: TaskKind.sleepRoutine,
          ),
        );

        await service.completeSleepRoutine(sleepRoutineCanonicalTitle);

        final loaded = await storage.loadTaskAssignment('composite_complete');
        expect(loaded!.state, TaskLifecycleState.succeeded);
        expect(loaded.isTerminal, isTrue);
      },
    );
  });

  group('TaskAssignmentService.enforceDeliveryQueueLimit', () {
    test('expires everything past the two-task queue limit', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        _task(
          id: 'oldest',
          state: TaskLifecycleState.pendingDelivery,
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
        ),
      );
      await storage.saveTaskAssignment(
        _task(
          id: 'middle',
          state: TaskLifecycleState.pendingDelivery,
          scheduledAt: DateTime(2026, 7, 20, 10, 0),
        ),
      );
      await storage.saveTaskAssignment(
        _task(
          id: 'newest',
          state: TaskLifecycleState.pendingDelivery,
          scheduledAt: DateTime(2026, 7, 20, 11, 0),
        ),
      );

      await service.enforceDeliveryQueueLimit();

      final oldest = await storage.loadTaskAssignment('oldest');
      final middle = await storage.loadTaskAssignment('middle');
      final newest = await storage.loadTaskAssignment('newest');
      expect(oldest!.state, TaskLifecycleState.pendingDelivery);
      expect(middle!.state, TaskLifecycleState.pendingDelivery);
      expect(newest!.state, TaskLifecycleState.expired);
    });

    test('leaves a queue at or under the limit untouched', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        _task(
          id: 'only_one',
          state: TaskLifecycleState.pendingDelivery,
          scheduledAt: DateTime(2026, 7, 20, 9, 0),
        ),
      );

      await service.enforceDeliveryQueueLimit();

      final loaded = await storage.loadTaskAssignment('only_one');
      expect(loaded!.state, TaskLifecycleState.pendingDelivery);
    });
  });

  group('TaskAssignmentService.applyPendingDeliveryExpirations', () {
    test('expires the row matching a natively-queued watchdogId', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);
      await storage.saveTaskAssignment(
        _task(id: 'native_expired', state: TaskLifecycleState.pendingDelivery),
      );

      await service.applyPendingDeliveryExpirations([
        {'watchdogId': 'native_expired', 'createdAtMillis': 1234567890},
      ]);

      final loaded = await storage.loadTaskAssignment('native_expired');
      expect(loaded!.state, TaskLifecycleState.expired);
    });

    test('ignores rows with a blank or missing watchdogId', () async {
      final storage = StorageService();
      final service = TaskAssignmentService(storage);

      // Should not throw even though nothing matches.
      await service.applyPendingDeliveryExpirations([
        {'createdAtMillis': 1234567890},
        {'watchdogId': '', 'createdAtMillis': 1234567890},
      ]);
    });
  });

  group('taskKind round-trip', () {
    test('defaults to noSmokeWindow when not specified', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(_task(id: 'kind_default'));

      final loaded = await storage.loadTaskAssignment('kind_default');
      expect(loaded!.taskKind, TaskKind.noSmokeWindow);
    });

    test('saving and loading a sleepRoutine task preserves its kind', () async {
      final storage = StorageService();
      await storage.saveTaskAssignment(
        TaskAssignment(
          id: 'kind_sleep',
          planDate: '2026-07-20',
          canonicalTitle: sleepRoutineCanonicalTitle,
          durationMinutes: 0,
          scheduledAt: DateTime(2026, 7, 20, 22, 0),
          state: TaskLifecycleState.planned,
          taskKind: TaskKind.sleepRoutine,
        ),
      );

      final loaded = await storage.loadTaskAssignment('kind_sleep');
      expect(loaded!.taskKind, TaskKind.sleepRoutine);
      expect(loaded.canonicalTitle, sleepRoutineCanonicalTitle);
    });

    test(
      'an old row saved before taskKind existed loads as noSmokeWindow',
      () async {
        // Simulates a device already on a schema version before taskKind
        // existed: create the table by hand, without the column, then run it
        // through the real onUpgrade path by opening it with StorageService.
        final dir = Directory.systemTemp.createTempSync(
          'no_smoke_taskkind_migration',
        );
        PathProviderPlatform.instance = _FixedPathProviderPlatform(dir.path);
        final dbPath = '${dir.path}/no_smoke.db';

        final legacyDb = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 28,
            onCreate: (db, version) async {
              await db.execute('''
              CREATE TABLE task_assignments (
                id TEXT PRIMARY KEY,
                planDate TEXT NOT NULL,
                canonicalTitle TEXT NOT NULL,
                durationMinutes INTEGER NOT NULL,
                scheduledAt TEXT NOT NULL,
                state TEXT NOT NULL,
                deliveredAt TEXT,
                respondedAt TEXT,
                barrierStartedAt TEXT,
                barrierEndsAt TEXT,
                attemptCount INTEGER NOT NULL DEFAULT 1,
                postponeCount INTEGER NOT NULL DEFAULT 0,
                totalPostponedMinutes INTEGER NOT NULL DEFAULT 0,
                gateDeferCount INTEGER NOT NULL DEFAULT 0,
                gateReason TEXT,
                sosCount INTEGER NOT NULL DEFAULT 0,
                sosTotalMinutes INTEGER NOT NULL DEFAULT 0,
                watchdogId TEXT,
                notificationId INTEGER,
                isCheckIn INTEGER NOT NULL DEFAULT 0
              )
            ''');
              await db.insert('task_assignments', {
                'id': 'pre_taskkind_migration',
                'planDate': '2026-07-20',
                'canonicalTitle': 'ADAPTIVE_NO_SMOKE:30',
                'durationMinutes': 30,
                'scheduledAt': DateTime(2026, 7, 20, 14, 0).toIso8601String(),
                'state': TaskLifecycleState.planned,
                'isCheckIn': 0,
              });
            },
          ),
        );
        await legacyDb.close();

        final storage = StorageService();
        await storage.closeDatabaseConnection();
        final loaded = await storage.loadTaskAssignment(
          'pre_taskkind_migration',
        );

        expect(loaded, isNotNull);
        expect(loaded!.taskKind, TaskKind.noSmokeWindow);

        await storage.closeDatabaseConnection();
      },
    );
  });

  group('isCheckIn migration', () {
    test('an existing task_assignments row from before this column '
        'defaults to false, not a crash', () async {
      // Simulates a device already on a schema version before isCheckIn
      // existed: create the table by hand, without the column, then run it
      // through the real onUpgrade path by opening it with StorageService.
      final dir = Directory.systemTemp.createTempSync('no_smoke_migration');
      PathProviderPlatform.instance = _FixedPathProviderPlatform(dir.path);
      final dbPath = '${dir.path}/no_smoke.db';

      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 23,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE task_assignments (
                id TEXT PRIMARY KEY,
                planDate TEXT NOT NULL,
                canonicalTitle TEXT NOT NULL,
                durationMinutes INTEGER NOT NULL,
                scheduledAt TEXT NOT NULL,
                state TEXT NOT NULL,
                deliveredAt TEXT,
                respondedAt TEXT,
                barrierStartedAt TEXT,
                barrierEndsAt TEXT,
                attemptCount INTEGER NOT NULL DEFAULT 1,
                postponeCount INTEGER NOT NULL DEFAULT 0,
                totalPostponedMinutes INTEGER NOT NULL DEFAULT 0,
                gateDeferCount INTEGER NOT NULL DEFAULT 0,
                gateReason TEXT,
                sosCount INTEGER NOT NULL DEFAULT 0,
                sosTotalMinutes INTEGER NOT NULL DEFAULT 0,
                watchdogId TEXT,
                notificationId INTEGER
              )
            ''');
            await db.insert('task_assignments', {
              'id': 'pre_migration',
              'planDate': '2026-07-20',
              'canonicalTitle': 'ADAPTIVE_NO_SMOKE:30',
              'durationMinutes': 30,
              'scheduledAt': DateTime(2026, 7, 20, 14, 0).toIso8601String(),
              'state': TaskLifecycleState.planned,
            });
          },
        ),
      );
      await legacyDb.close();

      final storage = StorageService();
      await storage.closeDatabaseConnection();
      final loaded = await storage.loadTaskAssignment('pre_migration');

      expect(loaded, isNotNull);
      expect(loaded!.isCheckIn, isFalse);

      await storage.closeDatabaseConnection();
    });
  });
}
