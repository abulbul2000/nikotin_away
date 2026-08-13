import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
import 'package:no_smoke/models/breath_acoustic_sample.dart';

Uint8List _pcm16Of(List<int> int16Samples) {
  final bytes = ByteData(int16Samples.length * 2);
  for (var i = 0; i < int16Samples.length; i++) {
    bytes.setInt16(i * 2, int16Samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

List<BreathAcousticSample> _silenceThenLoudThenSilence({
  int silenceMs = 1500,
  int loudMs = 1500,
  int trailingSilenceMs = 1500,
  int stepMs = 20,
  double silenceEnergy = 0.001,
  double loudEnergy = 0.3,
}) {
  final samples = <BreathAcousticSample>[];
  var t = 0;
  while (t < silenceMs) {
    samples.add(
      BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: silenceEnergy),
    );
    t += stepMs;
  }
  final loudStart = t;
  while (t < loudStart + loudMs) {
    samples.add(
      BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: loudEnergy),
    );
    t += stepMs;
  }
  final trailingStart = t;
  while (t < trailingStart + trailingSilenceMs) {
    samples.add(
      BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: silenceEnergy),
    );
    t += stepMs;
  }
  return samples;
}

void main() {
  group('computeRmsEnergy', () {
    final engine = BreathAcousticEngine();

    test('returns 0 for silence (all-zero samples)', () {
      final bytes = _pcm16Of(List.filled(100, 0));
      expect(engine.computeRmsEnergy(bytes), 0);
    });

    test('returns ~1.0 for full-scale samples', () {
      final bytes = _pcm16Of(List.filled(100, 32767));
      final energy = engine.computeRmsEnergy(bytes);
      expect(energy, closeTo(1.0, 0.01));
    });

    test('returns 0 for a chunk shorter than one sample', () {
      expect(engine.computeRmsEnergy(Uint8List(1)), 0);
    });
  });

  group('findExhaleOnsetMs / findExhaleOffsetMs', () {
    final engine = BreathAcousticEngine();

    test(
      'detects onset shortly after energy rises above the calibrated baseline',
      () {
        final samples = _silenceThenLoudThenSilence();
        final onset = engine.findExhaleOnsetMs(samples);
        expect(onset, isNotNull);
        expect(onset, greaterThanOrEqualTo(1500));
        expect(onset, lessThan(1700));
      },
    );

    test('detects offset shortly after energy drops back down', () {
      final samples = _silenceThenLoudThenSilence();
      final onset = engine.findExhaleOnsetMs(samples)!;
      final offset = engine.findExhaleOffsetMs(samples, onset);
      expect(offset, isNotNull);
      expect(offset, greaterThanOrEqualTo(3000));
      expect(offset, lessThan(3200));
    });

    test('returns null onset when energy never rises above baseline', () {
      final samples = _silenceThenLoudThenSilence(loudEnergy: 0.001);
      expect(engine.findExhaleOnsetMs(samples), isNull);
    });

    test(
      'returns null offset when energy never drops back down after onset',
      () {
        final samples = _silenceThenLoudThenSilence(trailingSilenceMs: 0);
        final onset = engine.findExhaleOnsetMs(samples)!;
        expect(engine.findExhaleOffsetMs(samples, onset), isNull);
      },
    );

    test('a loud tap/handling-noise spike in the very first sample does not '
        'poison the baseline and block later real-exhale detection '
        '(regression: real-device recorder startup noise)', () {
      final samples = <BreathAcousticSample>[
        // Recorder startup latency means the very first chunk can arrive
        // carrying the tap/handling noise from the user pressing "start",
        // wildly higher than the room's real noise floor.
        const BreathAcousticSample(
          millisecondsSinceStart: 1010,
          rmsEnergy: 0.20,
        ),
        ..._silenceThenLoudThenSilence(silenceEnergy: 0.012, loudEnergy: 0.15),
      ];
      final result = engine.analyze(samples);
      expect(result.exhaleDetected, isTrue);
    });

    test(
      'ignores brief spikes shorter than the debounce window (no false onset)',
      () {
        final samples = <BreathAcousticSample>[
          ...List.generate(
            60,
            (i) => BreathAcousticSample(
              millisecondsSinceStart: i * 20,
              rmsEnergy: 0.001,
            ),
          ),
          const BreathAcousticSample(
            millisecondsSinceStart: 1300,
            rmsEnergy: 0.3,
          ),
          const BreathAcousticSample(
            millisecondsSinceStart: 1320,
            rmsEnergy: 0.3,
          ),
          const BreathAcousticSample(
            millisecondsSinceStart: 1340,
            rmsEnergy: 0.001,
          ),
          const BreathAcousticSample(
            millisecondsSinceStart: 1360,
            rmsEnergy: 0.001,
          ),
        ];
        expect(engine.findExhaleOnsetMs(samples), isNull);
      },
    );
  });

  group('analyze', () {
    final engine = BreathAcousticEngine();

    test('returns exhaleDetected: false for an empty sample list', () {
      final result = engine.analyze(const []);
      expect(result.exhaleDetected, isFalse);
      expect(result.blowIntensity, isNull);
      expect(result.blowStability, isNull);
    });

    test('returns exhaleDetected: false when no exhale is ever detected', () {
      final samples = _silenceThenLoudThenSilence(loudEnergy: 0.001);
      final result = engine.analyze(samples);
      expect(result.exhaleDetected, isFalse);
    });

    test('returns exhaleDetected: false when the exhale never ends', () {
      final samples = _silenceThenLoudThenSilence(trailingSilenceMs: 0);
      final result = engine.analyze(samples);
      expect(result.exhaleDetected, isFalse);
    });

    test('detects a full exhale and derives plausible intensity/stability', () {
      final samples = _silenceThenLoudThenSilence();
      final result = engine.analyze(samples);
      expect(result.exhaleDetected, isTrue);
      expect(result.exhaleOnsetMs, isNotNull);
      expect(result.blowDurationMs, isNotNull);
      expect(result.blowDurationMs, greaterThan(0));
      // Steady 0.3 energy throughout the exhale -> low variance -> high stability
      // (the offset debounce window pulls in a few falling-edge samples too,
      // so this isn't exactly 1.0).
      expect(result.blowStability, greaterThan(0.8));
      // 0.3 / referenceLoudExhaleEnergy(0.25), clamped to 1.0.
      expect(result.blowIntensity, closeTo(1.0, 0.001));
    });

    test(
      'blowDurationMs measures only the exhale envelope, not elapsed time '
      'since the microphone started (regression: a rest interval or hold '
      'countdown before the exhale used to get folded into the reported '
      'duration)',
      () {
        // Simulates 20s of prior mic activity (a rest interval / earlier
        // attempt) followed by a clean ~4s exhale envelope, with
        // measurementStartMs anchored at the hold's start (20000ms) so the
        // preceding activity can't be picked up as the onset.
        final samples = _silenceThenLoudThenSilence(
          silenceMs: 20000,
          loudMs: 4000,
          trailingSilenceMs: 1500,
        );
        final result = engine.analyze(samples, measurementStartMs: 20000);
        expect(result.exhaleDetected, isTrue);
        // Onset is reported relative to measurementStartMs, not to the
        // recorder's own start — small (order of tens of ms), not ~20000.
        expect(result.exhaleOnsetMs, lessThan(500));
        // The exhale envelope itself is ~4000ms, not 20000+4000+.
        expect(result.blowDurationMs, closeTo(4000, 200));
      },
    );

    test('a noisier exhale yields lower stability than a steady one', () {
      final steady = _silenceThenLoudThenSilence(loudEnergy: 0.3);
      final noisySamples = <BreathAcousticSample>[];
      var t = 0;
      while (t < 1500) {
        noisySamples.add(
          BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: 0.001),
        );
        t += 20;
      }
      var toggle = true;
      final loudStart = t;
      while (t < loudStart + 1500) {
        noisySamples.add(
          BreathAcousticSample(
            millisecondsSinceStart: t,
            rmsEnergy: toggle ? 0.15 : 0.45,
          ),
        );
        toggle = !toggle;
        t += 20;
      }
      final trailingStart = t;
      while (t < trailingStart + 1500) {
        noisySamples.add(
          BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: 0.001),
        );
        t += 20;
      }

      final steadyResult = engine.analyze(steady);
      final noisyResult = engine.analyze(noisySamples);
      expect(steadyResult.exhaleDetected, isTrue);
      expect(noisyResult.exhaleDetected, isTrue);
      expect(noisyResult.blowStability, lessThan(steadyResult.blowStability!));
    });

    test('a quieter exhale yields lower intensity than a loud one', () {
      final loud = engine.analyze(_silenceThenLoudThenSilence(loudEnergy: 0.3));
      final quiet = engine.analyze(
        _silenceThenLoudThenSilence(loudEnergy: 0.05),
      );
      expect(loud.exhaleDetected, isTrue);
      expect(quiet.exhaleDetected, isTrue);
      expect(quiet.blowIntensity, lessThan(loud.blowIntensity!));
    });
  });

  group('findExhaleOnsetMs searchFromMs', () {
    /// The shape of a real first attempt: the user is told to breathe in
    /// deeply (loud), then to hold (quiet — this is the only honest baseline),
    /// then the "Başlat" prompt appears and they blow (loud again).
    List<BreathAcousticSample> inhaleThenHoldThenExhale({
      int inhaleMs = 1200,
      int holdMs = 3000,
      int exhaleMs = 2000,
      int stepMs = 20,
    }) {
      final samples = <BreathAcousticSample>[];
      var t = 0;
      void run(int durationMs, double energy) {
        final end = t + durationMs;
        while (t < end) {
          samples.add(
            BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: energy),
          );
          t += stepMs;
        }
      }

      run(inhaleMs, 0.25);
      run(holdMs, 0.001);
      run(exhaleMs, 0.30);
      return samples;
    }

    test('a buffer that opens on the inhale detects nothing at all', () {
      final engine = BreathAcousticEngine();

      // The baseline is read from the first samples, so when the loud inhale
      // is still in the buffer it *becomes* the noise floor: the threshold
      // lands above any real blow and the exhale is never seen. This is why
      // BreathTestPage clears the buffer when the hold begins — the fix lives
      // there, and this test pins down what it is protecting against.
      expect(engine.findExhaleOnsetMs(inhaleThenHoldThenExhale()), isNull);
    });

    /// What the buffer looks like after that clear: the quiet hold first (so
    /// the noise floor is honest), then whatever follows.
    List<BreathAcousticSample> holdThenExhale({
      int holdMs = 3000,
      int exhaleMs = 2000,
      int blipAtMs = -1,
      int stepMs = 20,
    }) {
      final samples = <BreathAcousticSample>[];
      var t = 0;
      while (t < holdMs) {
        final isBlip = blipAtMs >= 0 && t >= blipAtMs && t < blipAtMs + 200;
        samples.add(
          BreathAcousticSample(
            millisecondsSinceStart: t,
            rmsEnergy: isBlip ? 0.28 : 0.001,
          ),
        );
        t += stepMs;
      }
      final end = t + exhaleMs;
      while (t < end) {
        samples.add(
          BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: 0.30),
        );
        t += stepMs;
      }
      return samples;
    }

    test('finds the exhale once the hold provides the baseline', () {
      final engine = BreathAcousticEngine();
      final onset = engine.findExhaleOnsetMs(
        holdThenExhale(),
        searchFromMs: 3000,
      );

      expect(onset, isNotNull);
      expect(onset, greaterThanOrEqualTo(3000));
    });

    test('a noise during the hold is not taken as the exhale onset', () {
      final engine = BreathAcousticEngine();
      final samples = holdThenExhale(blipAtMs: 2000);

      // Someone shifting in their seat mid-hold. Unwindowed, that blip is the
      // first thing over the threshold and would auto-advance the attempt
      // before the user has blown.
      expect(engine.findExhaleOnsetMs(samples), lessThan(3000));

      final onset = engine.findExhaleOnsetMs(samples, searchFromMs: 3000);
      expect(onset, isNotNull);
      expect(onset, greaterThanOrEqualTo(3000));
    });

    test('a hold that stays quiet reports no exhale', () {
      final engine = BreathAcousticEngine();

      expect(
        engine.findExhaleOnsetMs(
          holdThenExhale(exhaleMs: 0),
          searchFromMs: 3000,
        ),
        isNull,
      );
    });
  });

  group('estimateSpirometry', () {
    final engine = BreathAcousticEngine();

    List<BreathAcousticSample> constantExhale({
      required int durationMs,
      double energy = 0.2,
      int stepMs = 20,
    }) {
      final samples = <BreathAcousticSample>[];
      var t = 0;
      while (t <= durationMs) {
        samples.add(
          BreathAcousticSample(millisecondsSinceStart: t, rmsEnergy: energy),
        );
        t += stepMs;
      }
      return samples;
    }

    test('returns null for fewer than 2 samples in the exhale window', () {
      final samples = [
        const BreathAcousticSample(millisecondsSinceStart: 0, rmsEnergy: 0.2),
      ];
      expect(engine.estimateSpirometry(samples, 0, 0), isNull);
    });

    test(
      'FEV1/FVC integral matches the closed-form value for constant energy',
      () {
        final samples = constantExhale(durationMs: 2000, energy: 0.2);
        final estimate = engine.estimateSpirometry(samples, 0, 2000)!;

        // Closed-form: energy * duration(seconds).
        expect(estimate.fvcEnergyIntegral, closeTo(0.2 * 2.0, 0.01));
        expect(estimate.fev1EnergyIntegral, closeTo(0.2 * 1.0, 0.01));
      },
    );

    test('a short, entirely front-loaded exhale has a ratio near 100%', () {
      // Whole exhale finishes inside the first second.
      final samples = constantExhale(durationMs: 600, energy: 0.2);
      final estimate = engine.estimateSpirometry(samples, 0, 600)!;

      expect(estimate.fev1FvcRatioPercent, closeTo(100, 0.5));
    });

    test(
      'a long, tapering exhale has a lower ratio than a short sharp one',
      () {
        final sharp = constantExhale(durationMs: 800, energy: 0.3);
        final sharpEstimate = engine.estimateSpirometry(sharp, 0, 800)!;

        // Energy tapers off well past the first second — most of the
        // integral accumulates after t=1000ms.
        final tapering = <BreathAcousticSample>[
          ...constantExhale(durationMs: 1000, energy: 0.3),
          ...List.generate(
            100,
            (i) => BreathAcousticSample(
              millisecondsSinceStart: 1020 + (i * 20),
              rmsEnergy: 0.25,
            ),
          ),
        ];
        final taperingEstimate = engine.estimateSpirometry(
          tapering,
          0,
          tapering.last.millisecondsSinceStart,
        )!;

        expect(
          taperingEstimate.fev1FvcRatioPercent,
          lessThan(sharpEstimate.fev1FvcRatioPercent),
        );
      },
    );

    test('guards against divide-by-zero for a near-zero-duration exhale', () {
      final samples = [
        const BreathAcousticSample(millisecondsSinceStart: 0, rmsEnergy: 0.0),
        const BreathAcousticSample(millisecondsSinceStart: 1, rmsEnergy: 0.0),
      ];
      final estimate = engine.estimateSpirometry(samples, 0, 1)!;
      expect(estimate.fev1FvcRatioPercent, 0.0);
      expect(estimate.fev1FvcRatioPercent.isNaN, isFalse);
    });

    test('interpolates the FEV1 point between two straddling samples', () {
      // Samples land at 900ms and 1100ms — the 1000ms mark is interpolated,
      // not snapped to either one.
      final samples = [
        const BreathAcousticSample(millisecondsSinceStart: 0, rmsEnergy: 0.2),
        const BreathAcousticSample(millisecondsSinceStart: 900, rmsEnergy: 0.2),
        const BreathAcousticSample(
          millisecondsSinceStart: 1100,
          rmsEnergy: 0.2,
        ),
        const BreathAcousticSample(
          millisecondsSinceStart: 2000,
          rmsEnergy: 0.2,
        ),
      ];
      final estimate = engine.estimateSpirometry(samples, 0, 2000)!;

      // Constant energy throughout -> integral at 1000ms should be close to
      // energy * 1.0s regardless of where samples happen to land.
      expect(estimate.fev1EnergyIntegral, closeTo(0.2 * 1.0, 0.02));
    });

    test('finds peak energy and its time within the exhale window', () {
      final samples = [
        const BreathAcousticSample(millisecondsSinceStart: 0, rmsEnergy: 0.1),
        const BreathAcousticSample(millisecondsSinceStart: 300, rmsEnergy: 0.5),
        const BreathAcousticSample(millisecondsSinceStart: 600, rmsEnergy: 0.2),
      ];
      final estimate = engine.estimateSpirometry(samples, 0, 600)!;

      expect(estimate.peakFlowAtMs, 300);
      expect(estimate.peakFlowIndex, greaterThan(0));
    });

    test('downsamples a long curve to the target point count', () {
      final samples = constantExhale(durationMs: 6000, energy: 0.2, stepMs: 10);
      final estimate = engine.estimateSpirometry(samples, 0, 6000)!;

      expect(estimate.curve.length, lessThanOrEqualTo(50));
      expect(estimate.curve, isNotEmpty);
    });
  });
}
