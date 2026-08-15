import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/task_assignment.dart';

/// Extended tests for TaskAssignment covering newer fields and edge cases
/// not covered by the existing task_assignment_storage_test.dart.
void main() {
  final now = DateTime(2025, 1, 15, 10, 0);

  TaskAssignment buildTask({
    String state = TaskLifecycleState.planned,
    int durationMinutes = 30,
    int attemptCount = 1,
    int postponeCount = 0,
    int totalPostponedMinutes = 0,
    int gateDeferCount = 0,
    String? gateReason,
    int sosCount = 0,
    int sosTotalMinutes = 0,
    bool isCheckIn = false,
    String taskKind = TaskKind.noSmokeWindow,
  }) {
    return TaskAssignment(
      id: 'task-1',
      planDate: '2025-01-15',
      canonicalTitle: 'ADAPTIVE_NO_SMOKE:$durationMinutes',
      durationMinutes: durationMinutes,
      scheduledAt: now,
      state: state,
      attemptCount: attemptCount,
      postponeCount: postponeCount,
      totalPostponedMinutes: totalPostponedMinutes,
      gateDeferCount: gateDeferCount,
      gateReason: gateReason,
      sosCount: sosCount,
      sosTotalMinutes: sosTotalMinutes,
      isCheckIn: isCheckIn,
      taskKind: taskKind,
    );
  }

  group('TaskLifecycleState.canTransition', () {
    test('planned -> accepted is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.planned,
          TaskLifecycleState.accepted,
        ),
        isTrue,
      );
    });

    test('accepted -> succeeded is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.accepted,
          TaskLifecycleState.succeeded,
        ),
        isTrue,
      );
    });

    test('accepted -> failedSmoked is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.accepted,
          TaskLifecycleState.failedSmoked,
        ),
        isTrue,
      );
    });

    test('accepted -> failedDeclined is NOT a direct transition', () {
      // From the code: accepted only allows awaitingConfirmation, barrierUnknown,
      // sosActive, succeeded, failedSmoked, failedMissed. Not failedDeclined.
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.accepted,
          TaskLifecycleState.failedDeclined,
        ),
        isFalse,
      );
    });

    test('delivered -> failedDeclined is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.delivered,
          TaskLifecycleState.failedDeclined,
        ),
        isTrue,
      );
    });

    test('postponed -> failedDeclined is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.postponed,
          TaskLifecycleState.failedDeclined,
        ),
        isTrue,
      );
    });

    test('accepted -> barrierUnknown is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.accepted,
          TaskLifecycleState.barrierUnknown,
        ),
        isTrue,
      );
    });

    test('succeeded -> anything is invalid (terminal)', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.succeeded,
          TaskLifecycleState.planned,
        ),
        isFalse,
      );
    });

    test('failedSmoked -> anything is invalid (terminal)', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.failedSmoked,
          TaskLifecycleState.accepted,
        ),
        isFalse,
      );
    });

    test('same state transition is always valid (no-op)', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.succeeded,
          TaskLifecycleState.succeeded,
        ),
        isTrue,
      );
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.planned,
          TaskLifecycleState.planned,
        ),
        isTrue,
      );
    });

    test('sosActive -> postponed is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.sosActive,
          TaskLifecycleState.postponed,
        ),
        isTrue,
      );
    });

    test('sosActive -> accepted is valid (resume barrier)', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.sosActive,
          TaskLifecycleState.accepted,
        ),
        isTrue,
      );
    });

    test('retrying -> failedMissed is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.retrying,
          TaskLifecycleState.failedMissed,
        ),
        isTrue,
      );
    });

    test('retrying -> retrying is valid (retry count increase)', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.retrying,
          TaskLifecycleState.retrying,
        ),
        isTrue,
      );
    });

    test('planned -> sosActive is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.planned,
          TaskLifecycleState.sosActive,
        ),
        isTrue,
      );
    });

    test('planned -> postponed is valid', () {
      expect(
        TaskLifecycleState.canTransition(
          TaskLifecycleState.planned,
          TaskLifecycleState.postponed,
        ),
        isTrue,
      );
    });

    test('unknown state transitions are invalid', () {
      expect(
        TaskLifecycleState.canTransition('invalid_state', 'planned'),
        isFalse,
      );
    });
  });

  group('TaskLifecycleState.outcomeFor', () {
    test('succeeded returns success', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.succeeded),
        AdaptiveTaskOutcome.success,
      );
    });

    test('failedSmoked returns smoked', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.failedSmoked),
        AdaptiveTaskOutcome.smoked,
      );
    });

    test('failedDeclined returns smoked (same as admission)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.failedDeclined),
        AdaptiveTaskOutcome.smoked,
      );
    });

    test('failedMissed returns missed', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.failedMissed),
        AdaptiveTaskOutcome.missed,
      );
    });

    test('expired returns null (not a user failure)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.expired),
        isNull,
      );
    });

    test('barrierUnknown returns null (not a user failure)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.barrierUnknown),
        isNull,
      );
    });

    test('planned returns null (not finished)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.planned),
        isNull,
      );
    });

    test('sosActive returns null (not finished)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.sosActive),
        isNull,
      );
    });

    test('postponed returns null (not finished)', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.postponed),
        isNull,
      );
    });
  });

  group('TaskAssignment.isTerminal', () {
    test('succeeded is terminal', () {
      expect(buildTask(state: TaskLifecycleState.succeeded).isTerminal, isTrue);
    });

    test('failedSmoked is terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.failedSmoked).isTerminal,
        isTrue,
      );
    });

    test('failedDeclined is terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.failedDeclined).isTerminal,
        isTrue,
      );
    });

    test('failedMissed is terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.failedMissed).isTerminal,
        isTrue,
      );
    });

    test('expired is terminal', () {
      expect(buildTask(state: TaskLifecycleState.expired).isTerminal, isTrue);
    });

    test('barrierUnknown is terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.barrierUnknown).isTerminal,
        isTrue,
      );
    });

    test('planned is not terminal', () {
      expect(buildTask(state: TaskLifecycleState.planned).isTerminal, isFalse);
    });

    test('accepted is not terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.accepted).isTerminal,
        isFalse,
      );
    });

    test('sosActive is not terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.sosActive).isTerminal,
        isFalse,
      );
    });

    test('postponed is not terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.postponed).isTerminal,
        isFalse,
      );
    });

    test('retrying is not terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.retrying).isTerminal,
        isFalse,
      );
    });

    test('delivered is not terminal', () {
      expect(
        buildTask(state: TaskLifecycleState.delivered).isTerminal,
        isFalse,
      );
    });
  });

  group('TaskAssignment.outcome getter', () {
    test('returns success for succeeded', () {
      expect(
        buildTask(state: TaskLifecycleState.succeeded).outcome,
        AdaptiveTaskOutcome.success,
      );
    });

    test('returns null for non-terminal states', () {
      expect(buildTask(state: TaskLifecycleState.planned).outcome, isNull);
      expect(buildTask(state: TaskLifecycleState.delivered).outcome, isNull);
      expect(buildTask(state: TaskLifecycleState.sosActive).outcome, isNull);
    });

    test('returns null for expired (system delay)', () {
      expect(buildTask(state: TaskLifecycleState.expired).outcome, isNull);
    });
  });

  group('TaskAssignment serialization', () {
    test('toJson/FromJson round-trip preserves all fields', () {
      final original = TaskAssignment(
        id: 'task-42',
        planDate: '2025-01-15',
        canonicalTitle: 'ADAPTIVE_NO_SMOKE:45',
        durationMinutes: 45,
        scheduledAt: now,
        state: TaskLifecycleState.accepted,
        deliveredAt: now.add(const Duration(minutes: 5)),
        respondedAt: now.add(const Duration(minutes: 10)),
        barrierStartedAt: now.add(const Duration(minutes: 10)),
        barrierEndsAt: now.add(const Duration(minutes: 55)),
        attemptCount: 2,
        postponeCount: 1,
        totalPostponedMinutes: 5,
        gateDeferCount: 1,
        gateReason: TaskGateReason.doNotDisturb,
        sosCount: 1,
        sosTotalMinutes: 3,
        watchdogId: 'wd-1',
        notificationId: 100,
        isCheckIn: true,
        taskKind: TaskKind.checkIn,
      );

      final json = original.toJson();
      final restored = TaskAssignment.fromJson(json);

      expect(restored.id, 'task-42');
      expect(restored.planDate, '2025-01-15');
      expect(restored.canonicalTitle, 'ADAPTIVE_NO_SMOKE:45');
      expect(restored.durationMinutes, 45);
      expect(restored.state, TaskLifecycleState.accepted);
      expect(restored.attemptCount, 2);
      expect(restored.postponeCount, 1);
      expect(restored.totalPostponedMinutes, 5);
      expect(restored.gateDeferCount, 1);
      expect(restored.gateReason, TaskGateReason.doNotDisturb);
      expect(restored.sosCount, 1);
      expect(restored.sosTotalMinutes, 3);
      expect(restored.watchdogId, 'wd-1');
      expect(restored.notificationId, 100);
      expect(restored.isCheckIn, isTrue);
      expect(restored.taskKind, TaskKind.checkIn);
      expect(restored.deliveredAt, isNotNull);
      expect(restored.barrierStartedAt, isNotNull);
      expect(restored.barrierEndsAt, isNotNull);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = <String, dynamic>{
        'id': 'task-1',
        'planDate': '2025-01-15',
        'canonicalTitle': 'ADAPTIVE_NO_SMOKE:30',
        'durationMinutes': 30,
        'scheduledAt': now.toIso8601String(),
        'state': TaskLifecycleState.planned,
      };

      final task = TaskAssignment.fromJson(json);

      expect(task.id, 'task-1');
      expect(task.attemptCount, 1);
      expect(task.postponeCount, 0);
      expect(task.totalPostponedMinutes, 0);
      expect(task.gateDeferCount, 0);
      expect(task.gateReason, isNull);
      expect(task.sosCount, 0);
      expect(task.sosTotalMinutes, 0);
      expect(task.isCheckIn, isFalse);
      expect(task.taskKind, TaskKind.noSmokeWindow);
      expect(task.isTerminal, isFalse);
    });

    test('fromJson handles null durationMinutes defaulting to 30', () {
      final json = <String, dynamic>{
        'id': 'task-2',
        'planDate': '2025-01-15',
        'canonicalTitle': 'ADAPTIVE_NO_SMOKE:30',
        'scheduledAt': now.toIso8601String(),
        'state': TaskLifecycleState.planned,
      };

      final task = TaskAssignment.fromJson(json);
      expect(task.durationMinutes, 30);
    });

    test('fromJson handles isCheckIn as 0/1 integer', () {
      final jsonWithCheckIn = <String, dynamic>{
        'id': 'task-3',
        'planDate': '2025-01-15',
        'canonicalTitle': 'CHECK_IN',
        'durationMinutes': 5,
        'scheduledAt': now.toIso8601String(),
        'state': TaskLifecycleState.planned,
        'isCheckIn': 1,
      };

      final task = TaskAssignment.fromJson(jsonWithCheckIn);
      expect(task.isCheckIn, isTrue);
    });
  });

  group('TaskAssignment.copyWith', () {
    test('changing state preserves all other fields', () {
      final original = buildTask(
        state: TaskLifecycleState.planned,
        attemptCount: 3,
        sosCount: 2,
      );
      final updated = original.copyWith(state: TaskLifecycleState.succeeded);

      expect(updated.state, TaskLifecycleState.succeeded);
      expect(updated.attemptCount, 3);
      expect(updated.sosCount, 2);
      expect(updated.id, original.id);
      expect(updated.planDate, original.planDate);
      expect(updated.durationMinutes, original.durationMinutes);
    });

    test('changing sosCount preserves state', () {
      final original = buildTask(
        state: TaskLifecycleState.accepted,
        sosCount: 1,
        sosTotalMinutes: 2,
      );
      final updated = original.copyWith(sosCount: 2, sosTotalMinutes: 5);

      expect(updated.sosCount, 2);
      expect(updated.sosTotalMinutes, 5);
      expect(updated.state, TaskLifecycleState.accepted);
    });
  });

  group('TaskGateReason constants', () {
    test('all gate reasons are non-empty strings', () {
      expect(TaskGateReason.doNotDisturb, isNotEmpty);
      expect(TaskGateReason.gaming, isNotEmpty);
      expect(TaskGateReason.driving, isNotEmpty);
      expect(TaskGateReason.fullscreen, isNotEmpty);
    });
  });

  group('TaskKind constants', () {
    test('all task kinds are distinct', () {
      final kinds = {
        TaskKind.noSmokeWindow,
        TaskKind.checkIn,
        TaskKind.sleepRoutine,
      };
      expect(kinds.length, 3);
    });

    test('noSmokeWindow is default', () {
      final task = buildTask();
      expect(task.taskKind, TaskKind.noSmokeWindow);
    });
  });
}
