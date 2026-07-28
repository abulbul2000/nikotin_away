import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/smoking_interval_service.dart';

/// The worked example from the design: awake 07:00–23:00, works 09:00–17:00
/// at a smoke-free site, 20 a day.
SmokingWindowInput _example({
  String wakeTime = '07:00',
  String sleepTime = '23:00',
  String? workStart = '09:00',
  String? workEnd = '17:00',
  String? workplaceRule = 'Hayır',
  List<(String, String)> breaks = const [],
  int dailyCigarettes = 20,
}) {
  return SmokingWindowInput(
    wakeTime: wakeTime,
    sleepTime: sleepTime,
    workStart: workStart,
    workEnd: workEnd,
    workplaceRule: workplaceRule,
    breaks: breaks,
    dailyCigarettes: dailyCigarettes,
  );
}

void main() {
  final service = SmokingIntervalService(random: Random(7));

  group('available smoking window', () {
    test('subtracts sleep and a smoke-free workday', () {
      // 16 waking hours minus an 8-hour shift.
      expect(service.availableSmokingMinutes(_example()), 8 * 60);
    });

    test('keeps the whole waking day when smoking is allowed at work', () {
      expect(
        service.availableSmokingMinutes(_example(workplaceRule: 'Evet')),
        16 * 60,
      );
    });

    test('hands back the breaks when only breaks are allowed', () {
      final input = _example(
        workplaceRule: 'Sadece molalarda',
        breaks: const [('12:00', '12:30'), ('15:00', '15:15')],
      );

      expect(service.availableSmokingMinutes(input), 8 * 60 + 45);
    });

    test('ignores a break entered outside working hours', () {
      // 19:00 is after the shift — already counted as free time, so adding it
      // again would inflate the window.
      final input = _example(
        workplaceRule: 'Sadece molalarda',
        breaks: const [('19:00', '19:30')],
      );

      expect(service.availableSmokingMinutes(input), 8 * 60);
    });

    test('handles a waking window that crosses midnight', () {
      final input = _example(
        wakeTime: '14:00',
        sleepTime: '06:00',
        workStart: '18:00',
        workEnd: '02:00',
      );

      // 16 hours awake, 8 of them on shift.
      expect(service.availableSmokingMinutes(input), 8 * 60);
    });

    test('never returns zero when work covers the whole waking day', () {
      final input = _example(
        wakeTime: '09:00',
        sleepTime: '17:00',
        workStart: '09:00',
        workEnd: '17:00',
      );

      expect(service.availableSmokingMinutes(input), greaterThanOrEqualTo(60));
    });
  });

  group('natural interval and starting barrier', () {
    test('divides the window by the daily count', () {
      // 480 minutes across 20 cigarettes.
      expect(service.naturalIntervalMinutes(_example()), 24);
    });

    test('starts a quarter above the habit', () {
      expect(service.startingBarrierMinutes(_example()), 30);
    });

    test('a heavier smoker gets a shorter, still-achievable barrier', () {
      final heavy = _example(dailyCigarettes: 40);

      expect(service.naturalIntervalMinutes(heavy), 12);
      expect(service.startingBarrierMinutes(heavy), 15);
    });

    test('survives a zero daily count without dividing by zero', () {
      expect(
        () => service.startingBarrierMinutes(_example(dailyCigarettes: 0)),
        returnsNormally,
      );
    });
  });

  group('weekly evolution', () {
    test('a good week stretches the barrier', () {
      expect(
        service.evolveWeeklyBarrierMinutes(
          currentMinutes: 30,
          goodWeek: true,
        ),
        35, // 30 * 1.15
      );
    });

    test('a bad week pulls it back by the same step', () {
      expect(
        service.evolveWeeklyBarrierMinutes(
          currentMinutes: 30,
          goodWeek: false,
        ),
        26, // 30 * 0.85, rounded
      );
    });

    test('never falls below the minimum worth issuing', () {
      var minutes = 12;
      for (var week = 0; week < 20; week++) {
        minutes = service.evolveWeeklyBarrierMinutes(
          currentMinutes: minutes,
          goodWeek: false,
        );
      }

      expect(minutes, SmokingIntervalService.minBarrierMinutes);
    });

    test('sustained good weeks reach the design curve', () {
      var minutes = service.startingBarrierMinutes(_example());
      for (var week = 0; week < 4; week++) {
        minutes = service.evolveWeeklyBarrierMinutes(
          currentMinutes: minutes,
          goodWeek: true,
        );
      }

      // The design projects roughly 52 minutes after four good weeks.
      expect(minutes, inInclusiveRange(50, 55));
    });
  });

  group('good-week test', () {
    test('needs both the count and the tasks to hold', () {
      expect(
        service.isGoodWeek(
          loggedCigarettes: 98,
          targetCigarettes: 112,
          taskSuccessRate: 0.78,
        ),
        isTrue,
      );
    });

    test('a good task rate does not excuse overshooting the count', () {
      expect(
        service.isGoodWeek(
          loggedCigarettes: 130,
          targetCigarettes: 112,
          taskSuccessRate: 0.9,
        ),
        isFalse,
      );
    });

    test('a low count does not excuse failing the tasks', () {
      expect(
        service.isGoodWeek(
          loggedCigarettes: 40,
          targetCigarettes: 112,
          taskSuccessRate: 0.2,
        ),
        isFalse,
      );
    });

    test('falls back to task success when nothing was logged', () {
      // Absent logs, not zero cigarettes — treating silence as a perfect week
      // would reward simply not using the button.
      expect(
        service.isGoodWeek(
          loggedCigarettes: null,
          targetCigarettes: 112,
          taskSuccessRate: 0.78,
        ),
        isTrue,
      );
      expect(
        service.isGoodWeek(
          loggedCigarettes: null,
          targetCigarettes: 112,
          taskSuccessRate: 0.3,
        ),
        isFalse,
      );
    });
  });

  test('implied daily target tracks the barrier', () {
    final input = _example();

    expect(
      service.impliedDailyTarget(input: input, barrierMinutes: 30),
      16, // 480 / 30
    );
    expect(
      service.impliedDailyTarget(input: input, barrierMinutes: 52),
      9,
    );
  });

  group('daily task count', () {
    test('stays within 4 and 8 across a wide range of inputs', () {
      for (var hours = 8; hours <= 20; hours += 1) {
        for (final rate in const [0.0, 0.5, 0.8, 0.95]) {
          final count = service.dailyTaskCount(
            input: _example(
              wakeTime: '06:00',
              sleepTime: '${(6 + hours) % 24}:00'.padLeft(5, '0'),
            ),
            movingSuccessRate: rate,
            movingFailureRate: 1 - rate,
            postponeRate: 0.2,
          );

          expect(count, inInclusiveRange(4, 8));
        }
      }
    });

    test('a longer waking day earns more tasks than a short one', () {
      // Averaged over many draws so the deliberate jitter doesn't decide it.
      double meanFor(String sleepTime) {
        final local = SmokingIntervalService(random: Random(1));
        var total = 0;
        for (var i = 0; i < 200; i++) {
          total += local.dailyTaskCount(
            input: _example(wakeTime: '07:00', sleepTime: sleepTime),
            movingSuccessRate: 0.5,
            movingFailureRate: 0.2,
            postponeRate: 0.2,
          );
        }
        return total / 200;
      }

      expect(meanFor('23:00'), greaterThan(meanFor('17:00')));
    });
  });
}
