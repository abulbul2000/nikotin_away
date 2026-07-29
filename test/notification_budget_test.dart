import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/notification_budget.dart';

void main() {
  const budget = NotificationBudget();
  final noon = DateTime(2026, 7, 30, 12, 0);

  BudgetDecision decide(
    NotificationKind kind, {
    String intensity = 'balanced',
    int sentToday = 0,
    DateTime? lastSentAt,
    int lowestPending = 99,
    DateTime? at,
  }) {
    return budget.decide(
      kind: kind,
      at: at ?? noon,
      intensity: intensity,
      offeredSentToday: sentToday,
      lastSentAt: lastSentAt,
      lowestPendingOfferedPriority: lowestPending,
    );
  }

  group('what the user is owed', () {
    test('a due task is never held back', () {
      // The task, the retries that chase it and the question at the end are
      // one conversation. Dropping any part leaves an unanswered obligation.
      for (final kind in [
        NotificationKind.taskAlert,
        NotificationKind.taskRetry,
        NotificationKind.taskConfirmation,
      ]) {
        final decision = decide(
          kind,
          sentToday: 99,
          lastSentAt: noon.subtract(const Duration(seconds: 5)),
        );
        expect(decision.allowed, isTrue, reason: '$kind must always pass');
      }
    });

    test('a dose the user put on the clock is never moved', () {
      final decision = decide(
        NotificationKind.medication,
        sentToday: 99,
        lastSentAt: noon,
      );

      expect(decision.allowed, isTrue);
    });
  });

  group('spacing', () {
    test('two notifications inside 25 minutes are one interruption', () {
      final decision = decide(
        NotificationKind.healthTip,
        lastSentAt: noon.subtract(const Duration(minutes: 10)),
      );

      expect(decision.allowed, isFalse);
      expect(decision.denial, BudgetDenial.tooSoon);
    });

    test('the gap applies across kinds, not per feature', () {
      // Each scheduler used to space only its own notifications, so every
      // one looked correct while the person got six of them at once.
      final decision = decide(
        NotificationKind.coachCommand,
        lastSentAt: noon.subtract(const Duration(minutes: 5)),
      );

      expect(decision.denial, BudgetDenial.tooSoon);
    });

    test('past the gap it goes through', () {
      final decision = decide(
        NotificationKind.healthTip,
        lastSentAt: noon.subtract(const Duration(minutes: 30)),
        lowestPending: 3,
      );

      expect(decision.allowed, isTrue);
    });
  });

  group('the daily budget follows what the user chose', () {
    test('gentle is quieter than strict', () {
      expect(
        NotificationBudget.dailyBudgetFor('gentle'),
        lessThan(NotificationBudget.dailyBudgetFor('strict')),
      );
    });

    test('an unknown value falls back to the middle setting', () {
      expect(
        NotificationBudget.dailyBudgetFor('nonsense'),
        NotificationBudget.dailyBudgetFor('balanced'),
      );
    });

    test('a spent budget closes the day for offered notifications', () {
      final decision = decide(
        NotificationKind.coachCommand,
        intensity: 'gentle',
        sentToday: NotificationBudget.dailyBudgetFor('gentle'),
      );

      expect(decision.allowed, isFalse);
      expect(decision.denial, BudgetDenial.budgetSpent);
    });

    test('strict still has room where gentle has run out', () {
      const spent = 3;
      expect(
        decide(
          NotificationKind.coachCommand,
          intensity: 'gentle',
          sentToday: spent,
          lowestPending: 4,
        ).allowed,
        isFalse,
      );
      expect(
        decide(
          NotificationKind.coachCommand,
          intensity: 'strict',
          sentToday: spent,
          lowestPending: 4,
        ).allowed,
        isTrue,
      );
    });
  });

  group('priority', () {
    test('a sitting nudge yields to a waiting breath reminder', () {
      // The budget is small, so without this a sedentary nudge in the
      // morning could spend the last slot and silence the measurement that
      // leaves a permanent hole in the trend if it is missed.
      final decision = decide(
        NotificationKind.sedentary,
        lowestPending: budget.priorityOf(NotificationKind.breathTest),
      );

      expect(decision.allowed, isFalse);
      expect(decision.denial, BudgetDenial.outranked);
    });

    test('the breath reminder does not yield to a coaching line', () {
      final decision = decide(
        NotificationKind.breathTest,
        lowestPending: budget.priorityOf(NotificationKind.coachCommand),
      );

      expect(decision.allowed, isTrue);
    });

    test('the measurement outranks every other offered kind', () {
      final breath = budget.priorityOf(NotificationKind.breathTest);
      for (final kind in [
        NotificationKind.weeklySurvey,
        NotificationKind.healthTip,
        NotificationKind.coachCommand,
        NotificationKind.sedentary,
      ]) {
        expect(
          budget.priorityOf(kind),
          greaterThan(breath),
          reason: '$kind should not be able to crowd out the measurement',
        );
      }
    });
  });

  test('every kind is classified, so none can slip through unranked', () {
    for (final kind in NotificationKind.values) {
      expect(budget.classOf(kind), isNotNull);
      expect(budget.priorityOf(kind), greaterThanOrEqualTo(0));
    }
  });
}
