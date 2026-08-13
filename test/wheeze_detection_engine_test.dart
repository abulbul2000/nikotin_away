import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/wheeze_detection_engine.dart';
import 'package:no_smoke/models/wheeze_acoustic_sample.dart';

/// Builds a PCM16LE chunk of a pure sine tone at [frequencyHz], [count]
/// samples long, at the engine's 16kHz sample rate.
Uint8List _sineChunk(double frequencyHz, int count, {double amplitude = 0.8}) {
  final bytes = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    final t = i / WheezeDetectionEngine.sampleRateHz;
    final value = amplitude * sin(2 * pi * frequencyHz * t);
    bytes.setInt16(i * 2, (value * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Builds a PCM16LE chunk of deterministic pseudo-white-noise, [count]
/// samples long — deterministic so tests are reproducible.
Uint8List _noiseChunk(int count, {double amplitude = 0.8, int seed = 42}) {
  final random = Random(seed);
  final bytes = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    final value = amplitude * (random.nextDouble() * 2 - 1);
    bytes.setInt16(i * 2, (value * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

Uint8List _silenceChunk(int count) {
  return Uint8List(count * 2);
}

/// Feeds [chunk] into [engine] one full window at a time and collects every
/// resulting sample, synthesizing millisecondsSinceStart from the window
/// duration (mirrors how BreathAudioService's stream callback would call
/// pushChunk in real time).
List<WheezeAcousticSample> _pushAllWindows(
  WheezeDetectionEngine engine,
  Uint8List chunk,
) {
  final samples = <WheezeAcousticSample>[];
  const bytesPerWindow = WheezeDetectionEngine.windowSizeSamples * 2;
  var offset = 0;
  var elapsedMs = 0;
  while (offset + bytesPerWindow <= chunk.length) {
    final window = chunk.sublist(offset, offset + bytesPerWindow);
    final sample = engine.pushChunk(Uint8List.fromList(window), elapsedMs);
    if (sample != null) {
      samples.add(sample);
    }
    offset += bytesPerWindow;
    elapsedMs += WheezeDetectionEngine.windowDurationMs.round();
  }
  return samples;
}

void main() {
  group('WheezeDetectionEngine.pushChunk windowing', () {
    test('returns null until a full window has accumulated', () {
      final engine = WheezeDetectionEngine();
      final halfWindow = _sineChunk(
        400,
        WheezeDetectionEngine.windowSizeSamples ~/ 2,
      );
      expect(engine.pushChunk(halfWindow, 0), isNull);
    });

    test('handles chunk sizes misaligned with the window boundary', () {
      final engine = WheezeDetectionEngine();
      // Feed odd-sized chunks (not a multiple of the window) and confirm
      // windows still complete correctly across call boundaries.
      final fullSignal = _sineChunk(
        400,
        WheezeDetectionEngine.windowSizeSamples * 3,
      );
      var offset = 0;
      var produced = 0;
      const oddChunkSamples = 333;
      while (offset < fullSignal.length) {
        final end = (offset + oddChunkSamples * 2).clamp(0, fullSignal.length);
        final chunk = fullSignal.sublist(offset, end);
        final sample = engine.pushChunk(Uint8List.fromList(chunk), offset);
        if (sample != null) {
          produced++;
        }
        offset = end;
      }
      expect(produced, 3);
    });
  });

  group('WheezeDetectionEngine.analyze detection', () {
    test('detects a sustained in-band tone (400Hz)', () {
      final engine = WheezeDetectionEngine();
      // 400Hz sits inside the 100-1000Hz wheeze band. Generate enough
      // windows to clear minConsecutiveWindowsForWheeze.
      final chunk = _sineChunk(
        400,
        WheezeDetectionEngine.windowSizeSamples *
            (WheezeDetectionEngine.minConsecutiveWindowsForWheeze + 3),
      );
      final samples = _pushAllWindows(engine, chunk);
      final analysis = engine.analyze(samples);

      expect(analysis.wheezeDetected, isTrue);
      expect(analysis.severityLevel, isNot('none'));
      expect(analysis.dominantFrequencyHz, isNotNull);
      expect(analysis.dominantFrequencyHz!, closeTo(400, 50));
    });

    test('does not detect an out-of-band tone (3000Hz)', () {
      final engine = WheezeDetectionEngine();
      final chunk = _sineChunk(
        3000,
        WheezeDetectionEngine.windowSizeSamples *
            (WheezeDetectionEngine.minConsecutiveWindowsForWheeze + 3),
      );
      final samples = _pushAllWindows(engine, chunk);
      final analysis = engine.analyze(samples);

      expect(analysis.wheezeDetected, isFalse);
      expect(analysis.severityLevel, 'none');
    });

    test('does not detect broadband white noise', () {
      final engine = WheezeDetectionEngine();
      final chunk = _noiseChunk(
        WheezeDetectionEngine.windowSizeSamples *
            (WheezeDetectionEngine.minConsecutiveWindowsForWheeze + 3),
      );
      final samples = _pushAllWindows(engine, chunk);
      final analysis = engine.analyze(samples);

      expect(analysis.wheezeDetected, isFalse);
    });

    test('does not detect silence', () {
      final engine = WheezeDetectionEngine();
      final chunk = _silenceChunk(
        WheezeDetectionEngine.windowSizeSamples *
            (WheezeDetectionEngine.minConsecutiveWindowsForWheeze + 3),
      );
      final samples = _pushAllWindows(engine, chunk);
      final analysis = engine.analyze(samples);

      expect(analysis.wheezeDetected, isFalse);
      expect(analysis.severityLevel, 'none');
    });

    test(
      'a single short in-band burst below the debounce floor is not a wheeze',
      () {
        final engine = WheezeDetectionEngine();
        // Fewer windows than minConsecutiveWindowsForWheeze — should not
        // register as a sustained wheeze, matching the app's cough-vs-wheeze
        // separation (a cough burst is short; a wheeze must persist).
        final shortBurst = _sineChunk(
          400,
          WheezeDetectionEngine.windowSizeSamples *
              (WheezeDetectionEngine.minConsecutiveWindowsForWheeze - 1),
        );
        final silenceAfter = _silenceChunk(
          WheezeDetectionEngine.windowSizeSamples * 4,
        );
        final samples = [
          ..._pushAllWindows(engine, shortBurst),
          ..._pushAllWindows(engine, silenceAfter),
        ];
        final analysis = engine.analyze(samples);

        expect(analysis.wheezeDetected, isFalse);
      },
    );

    test('empty sample list returns WheezeAnalysis.none', () {
      final engine = WheezeDetectionEngine();
      final analysis = engine.analyze(const []);
      expect(analysis.wheezeDetected, isFalse);
      expect(analysis.severityLevel, 'none');
      expect(analysis.severityScore, 0);
    });
  });

  group('WheezeDetectionEngine severity thresholds', () {
    test(
      'a longer, purer tone scores at least as high as a short, weak one',
      () {
        final shortEngine = WheezeDetectionEngine();
        final shortChunk = _sineChunk(
          400,
          WheezeDetectionEngine.windowSizeSamples *
              WheezeDetectionEngine.minConsecutiveWindowsForWheeze,
          amplitude: 0.4,
        );
        final shortAnalysis = shortEngine.analyze(
          _pushAllWindows(shortEngine, shortChunk),
        );

        final longEngine = WheezeDetectionEngine();
        final longChunk = _sineChunk(
          400,
          WheezeDetectionEngine.windowSizeSamples *
              (WheezeDetectionEngine.minConsecutiveWindowsForWheeze * 6),
          amplitude: 0.9,
        );
        final longAnalysis = longEngine.analyze(
          _pushAllWindows(longEngine, longChunk),
        );

        expect(shortAnalysis.wheezeDetected, isTrue);
        expect(longAnalysis.wheezeDetected, isTrue);
        expect(
          longAnalysis.severityScore,
          greaterThanOrEqualTo(shortAnalysis.severityScore),
        );
      },
    );

    test(
      'severity score stays within 0-100 and level matches score bucket',
      () {
        final engine = WheezeDetectionEngine();
        final chunk = _sineChunk(
          400,
          WheezeDetectionEngine.windowSizeSamples * 40,
          amplitude: 0.95,
        );
        final analysis = engine.analyze(_pushAllWindows(engine, chunk));

        expect(analysis.severityScore, inInclusiveRange(0, 100));
        if (analysis.severityScore < 35) {
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
