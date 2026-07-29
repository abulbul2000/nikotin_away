import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/task_assignment.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_task_assignment').path;
  }
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
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
    expect(
      TaskLifecycleState.outcomeFor(TaskLifecycleState.expired),
      isNull,
    );
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
    final resumed = await storage.transitionTaskAssignment(
      id: 'sos',
      state: TaskLifecycleState.postponed,
      postponeMinutes: 60,
      sosMinutes: 4,
    );

    expect(resumed!.state, TaskLifecycleState.postponed);
    expect(resumed.totalPostponedMinutes, 60);
    // Time spent breathing is tracked so it isn't charged against the
    // watchdog's silence window.
    expect(resumed.sosTotalMinutes, 4);
    expect(resumed.isTerminal, isFalse);
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
}
