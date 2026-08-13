import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/snoring_acoustic_engine.dart';
import 'package:no_smoke/models/breath_acoustic_sample.dart';

/// Builds a series of samples that alternate between a loud "snore burst"
/// and quiet gaps spaced [cycleMs] apart, for [burstCount] bursts —
/// mirrors the shape SleepProbeReceiver.kt's own energy envelope would
/// produce for a genuinely periodic snore pattern.
List<BreathAcousticSample> _periodicBursts({
  required int cycleMs,
  required int burstCount,
  double burstEnergy = 0.5,
  double quietEnergy = 0.02,
}) {
  final samples = <BreathAcousticSample>[];
  var elapsed = 0;
  for (var i = 0; i < burstCount; i++) {
    samples.add(
      BreathAcousticSample(
        millisecondsSinceStart: elapsed,
        rmsEnergy: burstEnergy,
      ),
    );
    elapsed += 50;
    samples.add(
      BreathAcousticSample(
        millisecondsSinceStart: elapsed,
        rmsEnergy: quietEnergy,
      ),
    );
    elapsed += cycleMs - 50;
  }
  return samples;
}

List<BreathAcousticSample> _constantEnergy(int count, double energy) {
  return List.generate(
    count,
    (i) => BreathAcousticSample(
      millisecondsSinceStart: i * SnoringAcousticEngine.windowMs,
      rmsEnergy: energy,
    ),
  );
}

void main() {
  group('SnoringAcousticEngine.analyze detection', () {
    test('detects a rhythmic pattern within the snore-cycle window', () {
      final engine = SnoringAcousticEngine();
      final samples = _periodicBursts(cycleMs: 700, burstCount: 6);
      final analysis = engine.analyze(samples);

      expect(analysis.snoreLikely, isTrue);
      expect(analysis.severityLevel, isNot('none'));
      expect(analysis.eventCount, greaterThanOrEqualTo(2));
    });

    test('does not detect bursts spaced faster than the snore-cycle floor', () {
      final engine = SnoringAcousticEngine();
      // 100ms apart is well under snoreMinCycleMs (300ms) -- rapid taps,
      // not snoring.
      final samples = _periodicBursts(cycleMs: 100, burstCount: 8);
      final analysis = engine.analyze(samples);

      expect(analysis.snoreLikely, isFalse);
    });

    test(
      'does not detect bursts spaced slower than the snore-cycle ceiling',
      () {
        final engine = SnoringAcousticEngine();
        // 3000ms apart is well over snoreMaxCycleMs (1500ms).
        final samples = _periodicBursts(cycleMs: 3000, burstCount: 4);
        final analysis = engine.analyze(samples);

        expect(analysis.snoreLikely, isFalse);
      },
    );

    test('does not detect constant, non-bursty energy', () {
      final engine = SnoringAcousticEngine();
      final samples = _constantEnergy(200, 0.3);
      final analysis = engine.analyze(samples);

      expect(analysis.snoreLikely, isFalse);
    });

    test('does not detect silence', () {
      final engine = SnoringAcousticEngine();
      final samples = _constantEnergy(200, 0.0);
      final analysis = engine.analyze(samples);

      expect(analysis.snoreLikely, isFalse);
      expect(analysis.severityLevel, 'none');
    });

    test('empty sample list returns SnoringAnalysis.none', () {
      final engine = SnoringAcousticEngine();
      final analysis = engine.analyze(const []);

      expect(analysis.snoreLikely, isFalse);
      expect(analysis.severityLevel, 'none');
      expect(analysis.severityScore, 0);
      expect(analysis.eventCount, 0);
    });

    test('a single burst alone is not enough to detect a pattern', () {
      final engine = SnoringAcousticEngine();
      final samples = [
        const BreathAcousticSample(millisecondsSinceStart: 0, rmsEnergy: 0.5),
      ];
      final analysis = engine.analyze(samples);

      expect(analysis.snoreLikely, isFalse);
      expect(analysis.eventCount, lessThan(2));
    });
  });

  group('SnoringAcousticEngine severity scoring', () {
    test('a more intense, more consistent pattern scores at least as high '
        'as a weaker one', () {
      final weakEngine = SnoringAcousticEngine();
      final weakSamples = _periodicBursts(
        cycleMs: 700,
        burstCount: 3,
        burstEnergy: 0.08,
      );
      final weakAnalysis = weakEngine.analyze(weakSamples);

      final strongEngine = SnoringAcousticEngine();
      final strongSamples = _periodicBursts(
        cycleMs: 700,
        burstCount: 10,
        burstEnergy: 0.9,
      );
      final strongAnalysis = strongEngine.analyze(strongSamples);

      expect(weakAnalysis.snoreLikely, isTrue);
      expect(strongAnalysis.snoreLikely, isTrue);
      expect(
        strongAnalysis.severityScore,
        greaterThanOrEqualTo(weakAnalysis.severityScore),
      );
    });

    test(
      'severity score stays within 0-100 and level matches score bucket',
      () {
        final engine = SnoringAcousticEngine();
        final samples = _periodicBursts(
          cycleMs: 600,
          burstCount: 12,
          burstEnergy: 0.95,
        );
        final analysis = engine.analyze(samples);

        expect(analysis.severityScore, inInclusiveRange(0, 100));
        if (analysis.severityScore <= 0) {
          expect(analysis.severityLevel, 'none');
        } else if (analysis.severityScore < 35) {
          expect(analysis.severityLevel, 'mild');
        } else if (analysis.severityScore < 65) {
          expect(analysis.severityLevel, 'moderate');
        } else {
          expect(analysis.severityLevel, 'severe');
        }
      },
    );
  });
}
