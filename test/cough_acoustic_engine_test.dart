import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/cough_acoustic_engine.dart';
import 'package:no_smoke/models/breath_acoustic_sample.dart';

/// Builds a 30s-equivalent sample stream (default 20ms step) with quiet
/// background energy and short loud "burst" windows at the given start
/// offsets — each burst is a handful of samples, matching a cough's short
/// (~150-350ms) energy spike rather than a sustained tone.
List<BreathAcousticSample> _streamWithBursts(
  List<int> burstStartMs, {
  int totalMs = 30000,
  int stepMs = 20,
  int burstDurationMs = 200,
  double quietEnergy = 0.002,
  double burstEnergy = 0.2,
}) {
  final samples = <BreathAcousticSample>[];
  var t = 0;
  while (t < totalMs) {
    final inBurst = burstStartMs.any(
      (start) => t >= start && t < start + burstDurationMs,
    );
    samples.add(
      BreathAcousticSample(
        millisecondsSinceStart: t,
        rmsEnergy: inBurst ? burstEnergy : quietEnergy,
      ),
    );
    t += stepMs;
  }
  return samples;
}

void main() {
  final engine = CoughAcousticEngine();

  group('findCoughEvents', () {
    test('an all-quiet recording has zero events', () {
      final samples = _streamWithBursts(const []);
      expect(engine.findCoughEvents(samples), isEmpty);
    });

    test('counts N well-separated bursts as N events', () {
      final samples = _streamWithBursts([2000, 8000, 15000, 22000]);
      expect(engine.findCoughEvents(samples).length, 4);
    });

    test(
      'a single burst spanning many above-threshold samples counts once',
      () {
        // One 400ms burst at 20ms steps is ~20 consecutive loud samples.
        final samples = _streamWithBursts(
          [5000],
          burstDurationMs: 400,
        );
        expect(engine.findCoughEvents(samples).length, 1);
      },
    );

    test('two bursts closer than minEventGapMs merge into one event', () {
      // Bursts at 5000 and 5000+80ms (well inside the 120ms debounce
      // window) with a short quiet gap between them should still read as
      // one cough, not two.
      final samples = <BreathAcousticSample>[];
      var t = 0;
      while (t < 10000) {
        final energy = (t >= 5000 && t < 5080) || (t >= 5100 && t < 5180)
            ? 0.2
            : 0.002;
        samples.add(
          BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: energy),
        );
        t += 20;
      }
      expect(engine.findCoughEvents(samples).length, 1);
    });

    test(
      'two bursts farther apart than minEventGapMs count as separate events',
      () {
        final samples = <BreathAcousticSample>[];
        var t = 0;
        while (t < 10000) {
          final energy = (t >= 5000 && t < 5080) || (t >= 5300 && t < 5380)
              ? 0.2
              : 0.002;
          samples.add(
            BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: energy),
          );
          t += 20;
        }
        expect(engine.findCoughEvents(samples).length, 2);
      },
    );
  });

  group('severityScore/severityLevel', () {
    test('zero coughs scores 0 and reads as normal', () {
      expect(engine.severityScore(0, 30), 0);
      expect(engine.severityLevel(engine.severityScore(0, 30)), 'normal');
    });

    test('1-2 coughs in a 30s test reads as mild', () {
      final score = engine.severityScore(2, 30);
      expect(engine.severityLevel(score), 'mild');
    });

    test('3-5 coughs in a 30s test reads as moderate', () {
      final score = engine.severityScore(4, 30);
      expect(engine.severityLevel(score), 'moderate');
    });

    test('10+ coughs in a 30s test reads as severe', () {
      final score = engine.severityScore(12, 30);
      expect(engine.severityLevel(score), 'severe');
    });

    test('cough count is normalized against test duration', () {
      // 5 coughs in a 60s test is half the density of 5 coughs in 30s —
      // should score lower (or equal), never higher.
      final score30s = engine.severityScore(5, 30);
      final score60s = engine.severityScore(5, 60);
      expect(score60s, lessThanOrEqualTo(score30s));
    });
  });

  group('analyze', () {
    test('no coughs detected leaves pattern metrics null', () {
      final result = engine.analyze(_streamWithBursts(const []));
      expect(result.coughCount, 0);
      expect(result.averageIntervalSeconds, isNull);
      expect(result.earlyBurstRatio, isNull);
      expect(result.peakIntensityScore, isNull);
    });

    test('a single cough leaves averageIntervalSeconds null', () {
      final result = engine.analyze(_streamWithBursts([5000]));
      expect(result.coughCount, 1);
      expect(result.averageIntervalSeconds, isNull);
      // A lone cough still has an early-burst ratio and peak intensity.
      expect(result.earlyBurstRatio, isNotNull);
      expect(result.peakIntensityScore, isNotNull);
    });

    test('averageIntervalSeconds reflects the gap between coughs', () {
      // Two coughs 10s apart -> ~10s average interval.
      final result = engine.analyze(_streamWithBursts([2000, 12000]));
      expect(result.coughCount, 2);
      expect(result.averageIntervalSeconds, closeTo(10.0, 0.1));
    });

    test('earlyBurstRatio is 1.0 when all coughs land in the first third', () {
      // 30s test, first third is 0-10000ms.
      final result = engine.analyze(_streamWithBursts([1000, 3000, 5000]));
      expect(result.earlyBurstRatio, 1.0);
    });

    test('earlyBurstRatio is 0.0 when all coughs land after the first third', () {
      final result = engine.analyze(_streamWithBursts([15000, 20000, 25000]));
      expect(result.earlyBurstRatio, 0.0);
    });

    test('earlyBurstRatio reflects a mixed pattern', () {
      // 1 of 2 coughs in the first third -> 0.5.
      final result = engine.analyze(_streamWithBursts([2000, 20000]));
      expect(result.earlyBurstRatio, 0.5);
    });

    test('peakIntensityScore is higher for a louder burst', () {
      final quiet = engine.analyze(
        _streamWithBursts([5000], burstEnergy: 0.05),
      );
      final loud = engine.analyze(
        _streamWithBursts([5000], burstEnergy: 0.4),
      );
      expect(loud.peakIntensityScore!, greaterThan(quiet.peakIntensityScore!));
    });

    test('severityScore/severityLevel are consistent with coughCount', () {
      final result = engine.analyze(_streamWithBursts([2000, 8000, 15000, 22000]));
      expect(result.coughCount, 4);
      expect(result.severityScore, engine.severityScore(4, 30));
      expect(result.severityLevel, engine.severityLevel(result.severityScore));
    });
  });
}
