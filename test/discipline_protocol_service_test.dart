import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/sensor_usage_event.dart';
import 'package:no_smoke/services/discipline_protocol_service.dart';

void main() {
  group('DisciplineProtocolService', () {
    test('high success rate tends to produce shorter unpredictable delays', () {
      final highService = DisciplineProtocolService(random: Random(7));
      final lowService = DisciplineProtocolService(random: Random(7));

      final highDurations = <int>[];
      final lowDurations = <int>[];
      for (var i = 0; i < 40; i += 1) {
        highDurations.add(
          highService
              .computeUnpredictableDelay(
                baseDelay: const Duration(minutes: 30),
                successRate: 0.9,
              )
              .inMinutes,
        );
        lowDurations.add(
          lowService
              .computeUnpredictableDelay(
                baseDelay: const Duration(minutes: 30),
                successRate: 0.2,
              )
              .inMinutes,
        );
      }

      final highAvg =
          highDurations.reduce((a, b) => a + b) / highDurations.length;
      final lowAvg = lowDurations.reduce((a, b) => a + b) / lowDurations.length;

      expect(highAvg, lessThan(lowAvg));
      expect(highDurations.every((v) => v >= 3), isTrue);
      expect(lowDurations.every((v) => v >= 3), isTrue);
    });

    test('generates sorted unpredictable moments inside allowed window', () {
      final service = DisciplineProtocolService(random: Random(42));
      final now = DateTime(2026, 7, 14, 10, 0);
      final sleepAt = DateTime(2026, 7, 14, 23, 0);

      final moments = service.generateUnpredictableMoments(
        now: now,
        sleepAt: sleepAt,
        riskyHours: const ['10:00-12:00', '18:00-21:00'],
        minCount: 5,
        successRate: 0.8,
      );

      expect(moments.length, greaterThanOrEqualTo(5));
      for (final moment in moments) {
        expect(moment.isAfter(now), isTrue);
        expect(moment.isBefore(sleepAt), isTrue);
      }

      final sorted = [...moments]..sort((a, b) => a.compareTo(b));
      expect(moments, sorted);
    });

    test(
      'flags suspicious behavior with strong movement during risky window',
      () {
        final service = DisciplineProtocolService();
        final start = DateTime(2026, 7, 14, 19, 0);
        final end = DateTime(2026, 7, 14, 19, 20);

        final events = [
          SensorUsageEvent(
            id: 'e1',
            createdAt: DateTime(2026, 7, 14, 19, 5),
            activityState: 'walking',
            accelerometerMagnitude: 2.2,
            gyroscopeMagnitude: 1.9,
            screenUnlockCount: 4,
            appUsageMinutes: 3,
            idleMinutes: 0,
            charging: false,
          ),
        ];

        final result = service.isSuspiciousDuringTask(
          events: events,
          riskyHours: const ['18:00-20:00'],
          startAt: start,
          endAt: end,
        );

        expect(result, isTrue);
      },
    );

    test('does not flag suspicious behavior for idle low-motion data', () {
      final service = DisciplineProtocolService();
      final start = DateTime(2026, 7, 14, 13, 0);
      final end = DateTime(2026, 7, 14, 13, 30);

      final events = [
        SensorUsageEvent(
          id: 'e2',
          createdAt: DateTime(2026, 7, 14, 13, 15),
          activityState: 'idle',
          accelerometerMagnitude: 0.25,
          gyroscopeMagnitude: 0.22,
          screenUnlockCount: 1,
          appUsageMinutes: 1,
          idleMinutes: 25,
          charging: true,
        ),
      ];

      final result = service.isSuspiciousDuringTask(
        events: events,
        riskyHours: const ['18:00-20:00'],
        startAt: start,
        endAt: end,
      );

      expect(result, isFalse);
    });

    test('a long barrier legitimately fits fewer than targetTaskCount, '
        'never a check-in filling the gap', () {
      // isCheckIn exists on the model for a future design, but no code
      // path produces one yet: a check-in would be a real notification+
      // overlay bound by the same gap >= barrierMinutes rule every other
      // slot follows (see discipline_protocol_adaptive_planner_test.dart's
      // "no task starts inside another one's window"), and a second fill
      // pass over the exact grid the first one already searched can never
      // find room the first one missed. A 240-minute barrier in a 15-hour
      // waking window legitimately holds only 3-4 slots — coming up short
      // of targetTaskCount is the honest outcome, not a gap to paper over.
      final service = DisciplineProtocolService(random: Random(11));
      final plan = service.buildDailyAdaptivePlan(
        now: DateTime(2026, 7, 14, 8, 0),
        sleepAt: DateTime(2026, 7, 14, 23, 0),
        riskyHours: const [],
        barrierMinutes: 240,
        targetTaskCount: 6,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: const [],
      );

      expect(plan.items.length, lessThan(6));
      expect(plan.items.any((item) => item.isCheckIn), isFalse);
      final starts = plan.items.map((i) => i.scheduledAt).toList()
        ..sort((a, b) => a.compareTo(b));
      for (var i = 1; i < starts.length; i++) {
        expect(
          starts[i].difference(starts[i - 1]).inMinutes,
          greaterThanOrEqualTo(240),
        );
      }
    });

    test('a short barrier with plenty of room reaches targetTaskCount '
        'without any check-ins', () {
      final service = DisciplineProtocolService(random: Random(3));
      final now = DateTime(2026, 7, 14, 8, 0);
      final sleepAt = DateTime(2026, 7, 14, 23, 0);

      final plan = service.buildDailyAdaptivePlan(
        now: now,
        sleepAt: sleepAt,
        riskyHours: const [],
        barrierMinutes: 30,
        targetTaskCount: 4,
        state: AdaptiveTaskState.initial(),
        hourlyProfiles: const [],
      );

      expect(plan.items.length, 4);
      expect(plan.items.any((item) => item.isCheckIn), isFalse);
    });
  });
}
