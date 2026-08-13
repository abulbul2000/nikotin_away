import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/step_trend_engine.dart';
import 'package:no_smoke/models/step_counter_sample.dart';

StepCounterSample _sample(DateTime at, int steps) {
  return StepCounterSample(
    id: 'sample_${at.millisecondsSinceEpoch}',
    createdAt: at,
    cumulativeSteps: steps,
  );
}

void main() {
  group('StepTrendEngine', () {
    final engine = StepTrendEngine();

    test('returns no daily counts with fewer than 2 samples', () {
      final result = engine.computeDailySteps([
        _sample(DateTime(2026, 1, 1), 100),
      ]);
      expect(result, isEmpty);
    });

    test('computes a simple same-day delta', () {
      final samples = [
        _sample(DateTime(2026, 1, 1, 8), 1000),
        _sample(DateTime(2026, 1, 1, 20), 4500),
      ];

      final result = engine.computeDailySteps(samples);

      expect(result, hasLength(1));
      expect(result.first.date, DateTime(2026, 1, 1));
      expect(result.first.steps, 3500);
    });

    test('attributes deltas across a day boundary to the later day', () {
      final samples = [
        _sample(DateTime(2026, 1, 1, 23, 50), 1000),
        _sample(DateTime(2026, 1, 2, 0, 5), 1200),
        _sample(DateTime(2026, 1, 2, 20), 8000),
      ];

      final result = engine.computeDailySteps(samples);

      expect(result, hasLength(1));
      expect(result.first.date, DateTime(2026, 1, 2));
      // (1200-1000) + (8000-1200) = 7000
      expect(result.first.steps, 7000);
    });

    test('treats a counter decrease as a reboot and uses the raw value '
        'instead of going negative', () {
      final samples = [
        _sample(DateTime(2026, 1, 1, 8), 9000),
        // Device rebooted; counter restarted from a small value.
        _sample(DateTime(2026, 1, 1, 20), 500),
      ];

      final result = engine.computeDailySteps(samples);

      expect(result, hasLength(1));
      expect(result.first.steps, 500);
    });

    test('totalStepsInRange sums only days within [start, end)', () {
      final samples = [
        _sample(DateTime(2025, 12, 31, 8), 0),
        _sample(DateTime(2026, 1, 1, 8), 1000),
        _sample(DateTime(2026, 1, 2, 8), 3000),
        _sample(DateTime(2026, 1, 3, 8), 4000),
      ];

      final total = engine.totalStepsInRange(
        samples,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 3),
      );

      // Day 1: 1000-0=1000, Day 2: 3000-1000=2000. Day 3 excluded (end is
      // exclusive).
      expect(total, 3000);
    });

    test('trendFor reports Increasing/Decreasing/Stable from first vs '
        'last day', () {
      final day1 = DateTime(2026, 1, 1);
      final day2 = DateTime(2026, 1, 2);

      expect(
        engine.trendFor([
          DailyStepCount(date: day1, steps: 1000),
          DailyStepCount(date: day2, steps: 3000),
        ]),
        'Increasing',
      );
      expect(
        engine.trendFor([
          DailyStepCount(date: day1, steps: 3000),
          DailyStepCount(date: day2, steps: 1000),
        ]),
        'Decreasing',
      );
      expect(
        engine.trendFor([DailyStepCount(date: day1, steps: 1000)]),
        'Stable',
      );
    });

    group('isMostRecentDaySedentary', () {
      test('false with fewer than 3 days of history', () {
        expect(
          engine.isMostRecentDaySedentary([
            DailyStepCount(date: DateTime(2026, 1, 1), steps: 5000),
            DailyStepCount(date: DateTime(2026, 1, 2), steps: 100),
          ]),
          isFalse,
        );
      });

      test('true when the most recent day is well below the prior average', () {
        expect(
          engine.isMostRecentDaySedentary([
            DailyStepCount(date: DateTime(2026, 1, 1), steps: 6000),
            DailyStepCount(date: DateTime(2026, 1, 2), steps: 5000),
            DailyStepCount(date: DateTime(2026, 1, 3), steps: 1500),
          ]),
          isTrue,
        );
      });

      test('false when the most recent day is close to the prior average', () {
        expect(
          engine.isMostRecentDaySedentary([
            DailyStepCount(date: DateTime(2026, 1, 1), steps: 6000),
            DailyStepCount(date: DateTime(2026, 1, 2), steps: 5000),
            DailyStepCount(date: DateTime(2026, 1, 3), steps: 4800),
          ]),
          isFalse,
        );
      });
    });

    group('isSedentaryWindow', () {
      test('false with fewer than 2 samples', () {
        expect(
          engine.isSedentaryWindow([_sample(DateTime(2026, 1, 1, 10), 100)]),
          isFalse,
        );
      });

      test(
        'false when the gap between samples is too short to mean anything',
        () {
          final samples = [
            _sample(DateTime(2026, 1, 1, 10, 0), 1000),
            _sample(DateTime(2026, 1, 1, 10, 20), 1000),
          ];
          expect(engine.isSedentaryWindow(samples), isFalse);
        },
      );

      test('true when a long gap has almost no step increase', () {
        final samples = [
          _sample(DateTime(2026, 1, 1, 9, 0), 1000),
          _sample(DateTime(2026, 1, 1, 11, 0), 1050),
        ];
        expect(engine.isSedentaryWindow(samples), isTrue);
      });

      test('false when a long gap has real step increase', () {
        final samples = [
          _sample(DateTime(2026, 1, 1, 9, 0), 1000),
          _sample(DateTime(2026, 1, 1, 11, 0), 3000),
        ];
        expect(engine.isSedentaryWindow(samples), isFalse);
      });

      test('handles a reboot reset without going negative', () {
        final samples = [
          _sample(DateTime(2026, 1, 1, 9, 0), 9000),
          _sample(DateTime(2026, 1, 1, 11, 0), 50),
        ];
        expect(engine.isSedentaryWindow(samples), isTrue);
      });
    });
  });
}
