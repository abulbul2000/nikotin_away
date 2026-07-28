import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/services/discipline_protocol_service.dart';

List<AdaptiveHourlyProfileEntry> _flatProfile() =>
    List<AdaptiveHourlyProfileEntry>.generate(
      24,
      (index) => AdaptiveHourlyProfileEntry.initial(index),
    );

void main() {
  group('Adaptive no-smoke planner', () {
    test('places the requested number of tasks around the week\'s barrier', () {
      final service = DisciplineProtocolService(random: Random(7));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 9, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['10:00-12:00', '18:00-21:00'],
        barrierMinutes: 30,
        targetTaskCount: 6,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      expect(plan.targetTaskCount, 6);
      expect(plan.items, hasLength(6));
      expect(plan.baseDurationMinutes, 30);
    });

    test('every task stands for the same weekly commitment', () {
      final service = DisciplineProtocolService(random: Random(3));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 9, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['10:00-12:00', '18:00-21:00'],
        barrierMinutes: 40,
        targetTaskCount: 8,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      // Jitter keeps the next task from being timeable off the last, but no
      // task drifts into being a different ask. There is deliberately no
      // within-day escalation any more: the barrier is the week's promise, so
      // a later task demanding materially more would be a promise the user
      // was never told about.
      for (final item in plan.items) {
        expect(item.durationMinutes, inInclusiveRange(36, 44));
      }
    });

    test('a longer barrier produces proportionally longer tasks', () {
      final service = DisciplineProtocolService(random: Random(11));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 9, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['10:00-12:00'],
        barrierMinutes: 160,
        targetTaskCount: 4,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      for (final item in plan.items) {
        expect(item.durationMinutes, inInclusiveRange(144, 176));
      }
    });

    test('the canonical title carries the same duration as the item', () {
      final service = DisciplineProtocolService(random: Random(5));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 9, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['10:00-12:00'],
        barrierMinutes: 52,
        targetTaskCount: 5,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      for (final item in plan.items) {
        expect(
          item.taskTitle,
          'ADAPTIVE_NO_SMOKE:${item.durationMinutes}',
        );
      }
    });

    test('hours the user struggles in ask for slightly less', () {
      final service = DisciplineProtocolService(random: Random(1));
      final strained = _flatProfile()
          .map((entry) => entry.copyWith(strainScore: 90))
          .toList();
      final easy = _flatProfile()
          .map((entry) => entry.copyWith(strainScore: 20))
          .toList();

      double meanDuration(List<AdaptiveHourlyProfileEntry> profile) {
        final plan = DisciplineProtocolService(random: Random(1))
            .buildDailyAdaptivePlan(
              now: DateTime(2026, 7, 16, 9, 0),
              sleepAt: DateTime(2026, 7, 16, 23, 0),
              riskyHours: const ['10:00-12:00', '18:00-21:00'],
              barrierMinutes: 60,
              targetTaskCount: 8,
              state: AdaptiveTaskState.initial(),
              hourlyProfiles: profile,
            );
        return plan.items
                .map((item) => item.durationMinutes)
                .reduce((a, b) => a + b) /
            plan.items.length;
      }

      expect(meanDuration(strained), lessThan(meanDuration(easy)));
      expect(service, isNotNull);
    });

    test('success outcome increases difficulty and does not reset', () {
      final service = DisciplineProtocolService(random: Random(7));
      final initial = AdaptiveTaskState.initial();

      final updated = service.evolveStateFromOutcome(
        current: initial,
        outcome: AdaptiveTaskOutcome.success,
        responseDelayMinutes: 6,
      );

      expect(updated.difficultyLevel, greaterThan(initial.difficultyLevel));
      expect(updated.dailyTaskCapacity, greaterThan(initial.dailyTaskCapacity));
      expect(updated.successStreak, 1);
      expect(updated.failureStreak, 0);
    });

    test('smoked outcome reduces difficulty but keeps floor > 0', () {
      final service = DisciplineProtocolService(random: Random(7));
      final state = AdaptiveTaskState.initial().copyWith(
        difficultyLevel: 1.2,
        dailyTaskCapacity: 4.0,
      );

      final updated = service.evolveStateFromOutcome(
        current: state,
        outcome: AdaptiveTaskOutcome.smoked,
        responseDelayMinutes: 4,
      );

      expect(
        updated.difficultyLevel,
        inInclusiveRange(1, state.difficultyLevel),
      );
      expect(
        updated.dailyTaskCapacity,
        inInclusiveRange(3, state.dailyTaskCapacity),
      );
      expect(updated.failureStreak, 1);
    });
  });
}
