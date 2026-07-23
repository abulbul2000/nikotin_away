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

    test('detects onset shortly after energy rises above the calibrated baseline', () {
      final samples = _silenceThenLoudThenSilence();
      final onset = engine.findExhaleOnsetMs(samples);
      expect(onset, isNotNull);
      expect(onset, greaterThanOrEqualTo(1500));
      expect(onset, lessThan(1700));
    });

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

    test('returns null offset when energy never drops back down after onset', () {
      final samples = _silenceThenLoudThenSilence(trailingSilenceMs: 0);
      final onset = engine.findExhaleOnsetMs(samples)!;
      expect(engine.findExhaleOffsetMs(samples, onset), isNull);
    });

    test(
      'a loud tap/handling-noise spike in the very first sample does not '
      'poison the baseline and block later real-exhale detection '
      '(regression: real-device recorder startup noise)',
      () {
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
      },
    );

    test('ignores brief spikes shorter than the debounce window (no false onset)', () {
      final samples = <BreathAcousticSample>[
        ...List.generate(
          60,
          (i) => BreathAcousticSample(
            millisecondsSinceStart: i * 20,
            rmsEnergy: 0.001,
          ),
        ),
        const BreathAcousticSample(millisecondsSinceStart: 1300, rmsEnergy: 0.3),
        const BreathAcousticSample(millisecondsSinceStart: 1320, rmsEnergy: 0.3),
        const BreathAcousticSample(millisecondsSinceStart: 1340, rmsEnergy: 0.001),
        const BreathAcousticSample(millisecondsSinceStart: 1360, rmsEnergy: 0.001),
      ];
      expect(engine.findExhaleOnsetMs(samples), isNull);
    });
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
      expect(result.holdDurationMs, isNotNull);
      expect(result.blowDurationMs, isNotNull);
      expect(result.blowDurationMs, greaterThan(0));
      // Steady 0.3 energy throughout the exhale -> low variance -> high stability
      // (the offset debounce window pulls in a few falling-edge samples too,
      // so this isn't exactly 1.0).
      expect(result.blowStability, greaterThan(0.8));
      // 0.3 / referenceLoudExhaleEnergy(0.25), clamped to 1.0.
      expect(result.blowIntensity, closeTo(1.0, 0.001));
    });

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
      final quiet = engine.analyze(_silenceThenLoudThenSilence(loudEnergy: 0.05));
      expect(loud.exhaleDetected, isTrue);
      expect(quiet.exhaleDetected, isTrue);
      expect(quiet.blowIntensity, lessThan(loud.blowIntensity!));
    });
  });
}
