import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/task_assignment.dart';

/// The end-of-window prompt asks "did you smoke during this time?", so **yes
/// is the failure**. The prompt it replaced asked "did you complete the
/// task?", where yes meant success.
///
/// Wiring the two the same way would invert every outcome the learning engine
/// records — the barrier would grow for people who kept smoking and shrink
/// for people who didn't, which is worse than having no feedback at all and
/// would be very hard to spot from the outside. These tests pin the mapping
/// down so a later edit can't quietly flip it.
void main() {
  group('confirmation polarity', () {
    test('answering YES to "did you smoke" is a failure', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.failedSmoked),
        AdaptiveTaskOutcome.smoked,
      );
    });

    test('answering NO to "did you smoke" is a success', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.succeeded),
        AdaptiveTaskOutcome.success,
      );
    });

    test('success and smoked never map to the same outcome', () {
      expect(
        TaskLifecycleState.outcomeFor(TaskLifecycleState.succeeded),
        isNot(TaskLifecycleState.outcomeFor(TaskLifecycleState.failedSmoked)),
      );
    });
  });

  group('lifecycle bookkeeping', () {
    TaskAssignment task({
      String state = TaskLifecycleState.delivered,
      int postponeCount = 0,
      int sosCount = 0,
    }) {
      return TaskAssignment(
        id: 't',
        planDate: '2026-07-20',
        canonicalTitle: 'ADAPTIVE_NO_SMOKE:30',
        durationMinutes: 30,
        scheduledAt: DateTime(2026, 7, 20, 14, 0),
        state: state,
        postponeCount: postponeCount,
        sosCount: sosCount,
      );
    }

    test('only finished states are terminal', () {
      expect(task(state: TaskLifecycleState.succeeded).isTerminal, isTrue);
      expect(task(state: TaskLifecycleState.failedMissed).isTerminal, isTrue);
      expect(task(state: TaskLifecycleState.expired).isTerminal, isTrue);

      // SOS suspends the task rather than ending it — the breathing exercise
      // runs and hands the user back to the same one.
      expect(task(state: TaskLifecycleState.sosActive).isTerminal, isFalse);
      expect(task(state: TaskLifecycleState.postponed).isTerminal, isFalse);
      expect(task(state: TaskLifecycleState.accepted).isTerminal, isFalse);
    });

    test('postpone and SOS counts survive a round trip', () {
      final restored = TaskAssignment.fromJson(
        task(postponeCount: 2, sosCount: 1).toJson(),
      );

      // Both are capped in the flow (two postpones, two SOS per task), so the
      // counts have to persist — otherwise a process restart would hand the
      // user a fresh allowance every time.
      expect(restored.postponeCount, 2);
      expect(restored.sosCount, 1);
    });

    test('an unfinished task reports no outcome', () {
      expect(task(state: TaskLifecycleState.delivered).outcome, isNull);
      expect(task(state: TaskLifecycleState.accepted).outcome, isNull);
      expect(task(state: TaskLifecycleState.sosActive).outcome, isNull);
    });
  });
}
