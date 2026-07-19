import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/services/discipline_protocol_service.dart';

void main() {
  group('Adaptive no-smoke planner', () {
    test('creates around 5 tasks and starts with short durations', () {
      final service = DisciplineProtocolService(random: Random(7));
      final now = DateTime(2026, 7, 16, 9, 0);
      final sleepAt = DateTime(2026, 7, 16, 23, 0);

      final plan = service.buildDailyAdaptivePlan(
        now: now,
        sleepAt: sleepAt,
        riskyHours: const ['10:00-12:00', '18:00-21:00'],
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: List<AdaptiveHourlyProfileEntry>.generate(
          24,
          (index) => AdaptiveHourlyProfileEntry.initial(index),
        ),
      );

      expect(plan.targetTaskCount, inInclusiveRange(4, 6));
      expect(plan.items.first.durationMinutes, inInclusiveRange(10, 20));
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

      expect(updated.difficultyLevel, inInclusiveRange(1, state.difficultyLevel));
      expect(updated.dailyTaskCapacity, inInclusiveRange(3, state.dailyTaskCapacity));
      expect(updated.failureStreak, 1);
    });
  });
}
