import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/services/discipline_protocol_service.dart';

void main() {
  group('Adaptive no-smoke planner', () {
    test('creates around 5 tasks and starts at the baseline duration tier', () {
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
      // Baseline tier for a fresh AdaptiveTaskState (difficultyLevel 1) is
      // 30-60 minutes -- see DisciplineProtocolService.resolveDurationTierRange.
      expect(plan.items.first.durationMinutes, inInclusiveRange(30, 60));
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

    test('duration tier escalates with earned difficulty and streak', () {
      final service = DisciplineProtocolService(random: Random(7));

      final baseline = service.resolveDurationTierRange(
        AdaptiveTaskState.initial(),
      );
      expect(baseline.$1, 30);
      expect(baseline.$2, 60);

      final midTier = service.resolveDurationTierRange(
        AdaptiveTaskState.initial().copyWith(difficultyLevel: 6.5),
      );
      expect(midTier.$1, greaterThan(baseline.$2));

      final weekTier = service.resolveDurationTierRange(
        AdaptiveTaskState.initial().copyWith(
          difficultyLevel: 9.2,
          successStreak: 12,
        ),
      );
      expect(weekTier.$1, 2 * 24 * 60);
      expect(weekTier.$2, 7 * 24 * 60);

      final monthTier = service.resolveDurationTierRange(
        AdaptiveTaskState.initial().copyWith(
          difficultyLevel: 10,
          successStreak: 25,
        ),
      );
      expect(monthTier.$1, monthTier.$2);
      expect(monthTier.$1, 30 * 24 * 60);
    });

    test(
      'a single-day plan collapses to one task once the multi-day tier is reached',
      () {
        final service = DisciplineProtocolService(random: Random(7));
        final now = DateTime(2026, 7, 16, 9, 0);
        final sleepAt = DateTime(2026, 7, 16, 23, 0);

        final plan = service.buildDailyAdaptivePlan(
          now: now,
          sleepAt: sleepAt,
          riskyHours: const ['10:00-12:00', '18:00-21:00'],
          state: AdaptiveTaskState.initial().copyWith(
            difficultyLevel: 9.2,
            successStreak: 12,
          ),
          hourlyProfiles: List<AdaptiveHourlyProfileEntry>.generate(
            24,
            (index) => AdaptiveHourlyProfileEntry.initial(index),
          ),
        );

        expect(plan.targetTaskCount, 1);
        expect(plan.items, hasLength(1));
        expect(
          plan.items.first.durationMinutes,
          inInclusiveRange(2 * 24 * 60, 7 * 24 * 60),
        );
      },
    );
  });
}
