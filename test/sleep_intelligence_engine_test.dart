import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/sleep_intelligence_engine.dart';
import 'package:no_smoke/models/sleep_probe_event.dart';

SleepProbeEvent _probe(DateTime at, {required bool screenOff}) {
  return SleepProbeEvent(
    id: 'p_${at.millisecondsSinceEpoch}',
    createdAt: at,
    screenOff: screenOff,
    charging: false,
  );
}

void main() {
  group('SleepIntelligenceEngine.estimateSleepWindow', () {
    final engine = SleepIntelligenceEngine();
    // Window 22:00 (1320) -> 08:00 (480), 45-minute interval.
    const windowStart = 22 * 60;
    const windowEnd = 8 * 60;
    const interval = 45;

    test('falls back to survey values when there are no probes', () {
      final result = engine.estimateSleepWindow(
        probes: const [],
        windowStartMinute: windowStart,
        windowEndMinute: windowEnd,
        intervalMinutes: interval,
        fallbackSleepTime: '23:30',
        fallbackWakeTime: '06:30',
      );

      expect(result.estimated, isFalse);
      expect(result.sleepTime, '23:30');
      expect(result.wakeTime, '06:30');
      expect(result.coverage, 0.0);
    });

    test('falls back when coverage is below the trust threshold', () {
      final base = DateTime(2026, 7, 22, 22, 0);
      // Only 3 probes for a window that expects ~14 -> coverage well under 0.6.
      final probes = [
        _probe(base, screenOff: true),
        _probe(base.add(const Duration(minutes: 45)), screenOff: true),
        _probe(base.add(const Duration(minutes: 90)), screenOff: true),
      ];

      final result = engine.estimateSleepWindow(
        probes: probes,
        windowStartMinute: windowStart,
        windowEndMinute: windowEnd,
        intervalMinutes: interval,
        fallbackSleepTime: '23:00',
        fallbackWakeTime: '07:00',
      );

      expect(result.estimated, isFalse);
      expect(result.sleepTime, '23:00');
      expect(result.coverage, lessThan(0.6));
    });

    test('estimates sleep/wake from the longest screen-off run when '
        'coverage is sufficient', () {
      final base = DateTime(2026, 7, 22, 22, 0);
      final probes = <SleepProbeEvent>[
        _probe(base, screenOff: false), // still awake, pre-sleep buffer
        _probe(
          base.add(const Duration(minutes: 45)),
          screenOff: true,
        ), // falls asleep here
        for (var i = 2; i <= 12; i++)
          _probe(base.add(Duration(minutes: 45 * i)), screenOff: true),
        _probe(
          base.add(const Duration(minutes: 45 * 13)),
          screenOff: false,
        ), // wakes up here
      ];

      final result = engine.estimateSleepWindow(
        probes: probes,
        windowStartMinute: windowStart,
        windowEndMinute: windowEnd,
        intervalMinutes: interval,
        fallbackSleepTime: '23:00',
        fallbackWakeTime: '07:00',
      );

      expect(result.estimated, isTrue);
      expect(result.sleepTime, '22:45');
      expect(result.wakeTime, '07:45');
      expect(result.coverage, greaterThanOrEqualTo(0.6));
    });

    test('a tightly-clustered probe burst does not pass the trust gate '
        'even when the raw count clears 60%', () {
      // Regression coverage: the trust gate only ever checked
      // probes.length / expectedCount, never whether those probes were
      // actually spread across the configured window. 9 probes packed
      // into the first 90 minutes of a 10-hour window (e.g. the app got
      // killed and restarted a few times right after the user fell
      // asleep, each restart firing a burst of catch-up probes, then
      // nothing for the rest of the night) clears 9/14 ≈ 64% coverage on
      // count alone, but says nothing trustworthy about the other ~8.5
      // hours — this must not be treated the same as genuine full-night
      // coverage.
      final base = DateTime(2026, 7, 22, 22, 0);
      final probes = [
        for (var i = 0; i < 9; i++)
          _probe(
            base.add(Duration(minutes: 10 * i)),
            screenOff: true,
          ), // all within the first 90 minutes
      ];

      final result = engine.estimateSleepWindow(
        probes: probes,
        windowStartMinute: windowStart,
        windowEndMinute: windowEnd,
        intervalMinutes: interval,
        fallbackSleepTime: '23:00',
        fallbackWakeTime: '07:00',
      );

      expect(result.estimated, isFalse);
      expect(result.sleepTime, '23:00');
      expect(result.wakeTime, '07:00');
    });

    test('a long mid-window gap in probe delivery is not silently treated as '
        'a real wake-up', () {
      // Similar spirit: 10 probes overall clears 10/14 ≈ 71% coverage,
      // but 8 of them sit in a dense pre-gap cluster and the rest arrive
      // only once probing resumes hours later — the multi-hour stretch
      // in between has zero data, not "awake" data, and should not be
      // read as a confidently short sleep window.
      final base = DateTime(2026, 7, 22, 22, 0);
      final probes = [
        for (var i = 0; i < 8; i++)
          _probe(base.add(Duration(minutes: 10 * i)), screenOff: true),
        // Probing resumes 6 hours later — a genuine multi-hour gap, not
        // a handful of missed 45-minute slots.
        _probe(base.add(const Duration(hours: 7)), screenOff: true),
        _probe(
          base.add(const Duration(hours: 7, minutes: 45)),
          screenOff: true,
        ),
      ];

      final result = engine.estimateSleepWindow(
        probes: probes,
        windowStartMinute: windowStart,
        windowEndMinute: windowEnd,
        intervalMinutes: interval,
        fallbackSleepTime: '23:00',
        fallbackWakeTime: '07:00',
      );

      expect(result.estimated, isFalse);
    });
  });
}
