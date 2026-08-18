import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_noise_engine.dart';
import 'package:no_smoke/models/breath_acoustic_sample.dart';
import 'package:no_smoke/models/breath_noise_baseline.dart';
import 'package:no_smoke/models/noise_check_result.dart';

List<BreathAcousticSample> _samples(List<double> energies) {
  return [
    for (var i = 0; i < energies.length; i++)
      BreathAcousticSample(
        millisecondsSinceStart: i * 100,
        rmsEnergy: energies[i],
      ),
  ];
}

void main() {
  group('BreathNoiseEngine.computeReferenceLevel', () {
    final engine = BreathNoiseEngine();

    test('empty history returns the default reference level', () {
      expect(
        engine.computeReferenceLevel(const []),
        BreathNoiseEngine.defaultReferenceLevel,
      );
    });

    test('uses median, not mean — a single outlier door-slam does not skew '
        'the reference', () {
      final base = DateTime(2026, 1, 1);
      final baselines = [
        BreathNoiseBaseline(measuredAt: base, level: 0.01),
        BreathNoiseBaseline(
          measuredAt: base.add(const Duration(days: 1)),
          level: 0.011,
        ),
        BreathNoiseBaseline(
          measuredAt: base.add(const Duration(days: 2)),
          level: 0.009,
        ),
        // Outlier: door slam during one baseline capture.
        BreathNoiseBaseline(
          measuredAt: base.add(const Duration(days: 3)),
          level: 0.5,
        ),
      ];

      final reference = engine.computeReferenceLevel(baselines);
      // Median of [0.009, 0.01, 0.011, 0.5] is (0.01+0.011)/2 = 0.0105 —
      // nowhere near the mean (~0.13), which the outlier would have pulled
      // up dramatically.
      expect(reference, closeTo(0.0105, 0.0001));
    });

    test('only considers the most recent referenceSampleCount baselines', () {
      final base = DateTime(2026, 1, 1);
      // 15 old, very noisy baselines, followed by 10 recent, quiet ones.
      final oldNoisy = List.generate(
        15,
        (i) => BreathNoiseBaseline(
          measuredAt: base.add(Duration(days: i)),
          level: 0.9,
        ),
      );
      final recentQuiet = List.generate(
        BreathNoiseEngine.referenceSampleCount,
        (i) => BreathNoiseBaseline(
          measuredAt: base.add(Duration(days: 100 + i)),
          level: 0.01,
        ),
      );

      final reference = engine.computeReferenceLevel([
        ...oldNoisy,
        ...recentQuiet,
      ]);
      expect(reference, closeTo(0.01, 0.0001));
    });
  });

  group('BreathNoiseEngine.evaluate — relative thresholds', () {
    final engine = BreathNoiseEngine();
    const reference = 0.01;

    test('level near reference is quiet', () {
      final result = engine.evaluate(
        _samples([0.009, 0.01, 0.011, 0.01, 0.009]),
        referenceLevel: reference,
      );
      expect(result.level, NoiseLevel.quiet);
      expect(result.isNoisy, isFalse);
      expect(result.shouldMarkRecordAsNoisy, isFalse);
    });

    test('level around 2x reference triggers the warning band', () {
      final result = engine.evaluate(
        _samples([0.021, 0.02, 0.022, 0.021, 0.02]),
        referenceLevel: reference,
      );
      expect(result.level, NoiseLevel.warning);
      expect(result.isNoisy, isTrue);
      expect(result.shouldMarkRecordAsNoisy, isFalse);
    });

    test('level around 4x reference is loud and marks the record', () {
      final result = engine.evaluate(
        _samples([0.041, 0.04, 0.042, 0.041, 0.04]),
        referenceLevel: reference,
      );
      expect(result.level, NoiseLevel.loud);
      expect(result.isNoisy, isTrue);
      expect(result.shouldMarkRecordAsNoisy, isTrue);
    });

    test('empty samples default to quiet rather than throwing', () {
      final result = engine.evaluate(const [], referenceLevel: reference);
      expect(result.level, NoiseLevel.quiet);
    });
  });

  group('BreathNoiseEngine.evaluate — volatility', () {
    final engine = BreathNoiseEngine();

    test('a steady hum has low volatility even if somewhat loud', () {
      final result = engine.evaluate(
        _samples([0.02, 0.021, 0.019, 0.02, 0.021]),
        referenceLevel: 0.01,
      );
      expect(result.volatility, lessThan(0.01));
    });

    test('speech/TV-style sudden spikes produce high volatility even at a '
        'similar median level', () {
      final steady = engine.evaluate(
        _samples([0.02, 0.021, 0.019, 0.02, 0.021]),
        referenceLevel: 0.01,
      );
      final spiky = engine.evaluate(
        _samples([0.005, 0.08, 0.004, 0.09, 0.006]),
        referenceLevel: 0.01,
      );
      expect(spiky.volatility, greaterThan(steady.volatility));
    });
  });

  group('BreathNoiseEngine.evaluate — volatility affects level (regression '
      'coverage)', () {
    final engine = BreathNoiseEngine();

    // Regression coverage: volatility was computed and returned on every
    // NoiseCheckResult but never actually influenced `level` — a burst
    // brief enough to leave the median near the reference level (a TV
    // turning on partway through the ambient window, someone saying one
    // sentence) used to read as 'quiet' exactly like true silence,
    // despite volatility clearly distinguishing the two (see the
    // 'speech/TV-style sudden spikes' test above).
    test('a brief mid-window spike is at least a warning even though the '
        'median alone would call it quiet', () {
      final result = engine.evaluate(
        _samples([0.005, 0.08, 0.004, 0.09, 0.006]),
        referenceLevel: 0.01,
      );
      // Median of this fixture is 0.006 — below the 2x-reference
      // warning threshold on level alone.
      expect(result.measuredLevel, lessThan(0.01 * 2));
      expect(result.level, isNot(NoiseLevel.quiet));
    });

    test('a steady hum at a similar level stays quiet', () {
      final result = engine.evaluate(
        _samples([0.009, 0.011, 0.01, 0.009, 0.011]),
        referenceLevel: 0.01,
      );
      expect(result.level, NoiseLevel.quiet);
    });
  });

  group('BreathNoiseEngine.evaluateDuringAttempt', () {
    final engine = BreathNoiseEngine();

    test('flags a mid-attempt spike (e.g. someone starts talking) the same '
        'way the pre-test check would', () {
      final result = engine.evaluateDuringAttempt(
        _samples([0.041, 0.04, 0.042, 0.041, 0.04]),
        referenceLevel: 0.01,
      );
      expect(result.level, NoiseLevel.loud);
    });
  });
}
