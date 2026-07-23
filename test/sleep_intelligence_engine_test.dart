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
          _probe(
            base.add(Duration(minutes: 45 * i)),
            screenOff: true,
          ),
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
  });
}
