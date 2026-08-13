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

    test('no task starts inside another one\'s window', () {
      // The gap between tasks was a fixed 45 minutes regardless of how long
      // each one ran. The barrier grows about 15% a week, so at 90 minutes a
      // second task could be issued half an hour into the first one's
      // window: two full-screen alerts, two confirmation prompts and two
      // overlapping watchdogs for one stretch of time.
      for (var seed = 0; seed < 25; seed++) {
        final service = DisciplineProtocolService(random: Random(seed));
        final plan = service.buildDailyAdaptivePlan(
          now: DateTime(2026, 7, 16, 8, 0),
          sleepAt: DateTime(2026, 7, 16, 23, 0),
          riskyHours: const ['10:00-12:00', '18:00-21:00'],
          barrierMinutes: 90,
          targetTaskCount: 8,
          state: AdaptiveTaskState.initial(),
          hourlyProfiles: _flatProfile(),
        );

        final starts = plan.items.map((item) => item.scheduledAt).toList()
          ..sort((a, b) => a.compareTo(b));
        for (var i = 1; i < starts.length; i++) {
          final gap = starts[i].difference(starts[i - 1]).inMinutes;
          expect(
            gap,
            greaterThanOrEqualTo(90),
            reason: 'seed $seed: tasks $gap min apart on a 90 min barrier',
          );
        }
      }
    });

    test('a long barrier still fills the day rather than thinning out', () {
      final service = DisciplineProtocolService(random: Random(11));
      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 8, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['10:00-12:00', '18:00-21:00'],
        barrierMinutes: 90,
        targetTaskCount: 6,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      // 15 waking hours at 90 minutes apart leaves room for the full count.
      // Spacing tasks properly must not quietly turn a daily rhythm into two
      // contacts a day — the 4–8 range is a promise about how the programme
      // feels.
      expect(plan.items, hasLength(6));
    });

    test('a barrier too long for the day yields fewer tasks, not overlaps', () {
      final service = DisciplineProtocolService(random: Random(5));
      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 18, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['18:00-21:00'],
        barrierMinutes: 120,
        targetTaskCount: 8,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
      );

      // Five hours cannot hold eight two-hour commitments. Asking anyway
      // would mean telling someone to begin a fresh stretch while still
      // inside the last one.
      expect(plan.items.length, lessThan(8));
      final starts = plan.items.map((item) => item.scheduledAt).toList()
        ..sort((a, b) => a.compareTo(b));
      for (var i = 1; i < starts.length; i++) {
        expect(
          starts[i].difference(starts[i - 1]).inMinutes,
          greaterThanOrEqualTo(120),
        );
      }
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
        expect(item.taskTitle, 'ADAPTIVE_NO_SMOKE:${item.durationMinutes}');
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

    test('no task lands inside a blocked working window', () {
      final service = DisciplineProtocolService(random: Random(9));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 7, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['08:00-20:00'],
        barrierMinutes: 30,
        targetTaskCount: 8,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
        // A smoke-free 09:00-17:00 shift with a lunch break left open.
        blockedWindows: const [('09:00', '12:00'), ('12:30', '17:00')],
      );

      expect(plan.items, isNotEmpty);
      for (final item in plan.items) {
        final minutes = item.scheduledAt.hour * 60 + item.scheduledAt.minute;
        final inMorningShift = minutes >= 9 * 60 && minutes < 12 * 60;
        final inAfternoonShift = minutes >= 12 * 60 + 30 && minutes < 17 * 60;

        expect(
          inMorningShift || inAfternoonShift,
          isFalse,
          reason: 'task at ${item.scheduledAt} fell inside the shift',
        );
      }
    });

    test('issues fewer tasks rather than forcing them into blocked time', () {
      final service = DisciplineProtocolService(random: Random(4));

      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 16, 7, 0),
        sleepAt: DateTime(2026, 7, 16, 23, 0),
        riskyHours: const ['08:00-22:00'],
        barrierMinutes: 30,
        targetTaskCount: 8,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: _flatProfile(),
        // A long shift leaves barely any room; with a 45-minute minimum gap
        // eight tasks simply don't fit.
        blockedWindows: const [('08:00', '20:00')],
      );

      expect(plan.items.length, lessThan(8));
      expect(plan.targetTaskCount, plan.items.length);
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
