import 'dart:math';
import 'dart:typed_data';

import '../models/breath_acoustic_sample.dart';

class BreathAcousticAnalysis {
  final bool exhaleDetected;
  final int? holdDurationMs;
  final int? blowDurationMs;
  final double? blowIntensity;
  final double? blowStability;

  const BreathAcousticAnalysis({
    required this.exhaleDetected,
    this.holdDurationMs,
    this.blowDurationMs,
    this.blowIntensity,
    this.blowStability,
  });
}

/// Detects the exhale portion of a breath-test attempt from a stream of
/// energy samples and derives real intensity/stability metrics from it —
/// replacing the previous proxy (`estimateBlowIntensity`/
/// `estimateBlowStabilityFromAttempts` in BreathTestEngine), which was only
/// ever derived from how consistently the user tapped a button, never from
/// an actual measurement of the breath itself.
///
/// Pure rule-based DSP (energy envelope + adaptive threshold + debounce),
/// deliberately not machine learning — matches the published research this
/// is based on (energy-envelope/adaptive-threshold exhale detection is the
/// standard technique in the smartphone respiratory-audio literature, not
/// a deep model) and keeps this consistent with the rest of the app's
/// fully offline, deterministic, explainable engines.
class BreathAcousticEngine {
  // Deliberately on the sensitive side rather than tuned tight: mic gain,
  // AGC behavior, and case/build muffling vary a lot across manufacturers,
  // and this has only been verified against one physical device. A lower
  // multiplier catches a smaller relative jump above the noise floor, which
  // trades a bit more false-positive risk (mitigated by the 3-sample
  // debounce and the "hold your breath" phase before listening starts) for
  // a much lower chance of silently failing to detect a real exhale on a
  // phone whose mic has a smaller loud/quiet dynamic range than the device
  // this was tuned on.
  static const double onsetMultiplier = 1.8;
  static const double onsetAbsoluteMargin = 0.008;
  static const double offsetMultiplier = 1.4;
  static const int onsetDebounceSamples = 3;
  static const int offsetDebounceSamples = 4;
  static const double _minBaseline = 0.002;

  // The first samples after the recorder starts are unreliable: on real
  // devices the platform recorder itself has ~1s of startup latency (so the
  // very first chunk can land near the *end* of the nominal calibration
  // window instead of the start of it), and whatever chunk arrives first
  // tends to carry the tap/handling noise from the user just having pressed
  // the start button — not the room's actual noise floor. Skipping a few
  // samples by *index* (not wall-clock time, which the startup latency
  // makes unreliable) before sampling the baseline avoids both problems.
  // The calibration sample count is deliberately generous (not the bare
  // minimum) — a noise-floor estimate from more samples is more stable
  // and less likely to be thrown off by one stray sound on any given
  // device/environment.
  static const int calibrationSkipSamples = 3;
  static const int calibrationSampleCount = 12;
  static const int _calibrationSampleTotal =
      calibrationSkipSamples + calibrationSampleCount;

  /// Converts a raw little-endian PCM16 mono chunk into a single normalized
  /// (roughly 0..1) RMS energy value. The only thing callers should ever
  /// keep from a chunk of raw audio — the bytes themselves are discarded
  /// immediately after this call by [BreathAudioService].
  double computeRmsEnergy(Uint8List pcm16Bytes) {
    if (pcm16Bytes.length < 2) {
      return 0;
    }
    final byteData = ByteData.sublistView(pcm16Bytes);
    final sampleCount = pcm16Bytes.length ~/ 2;
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    return sqrt(sumSquares / sampleCount);
  }

  /// Median (not mean) of a run of samples picked by *index*, skipping the
  /// first [calibrationSkipSamples] — median because even after skipping the
  /// likely-contaminated leading samples, a single remaining handling-noise
  /// spike shouldn't be able to drag a small-sample-count average far off
  /// the true noise floor the way it would a mean.
  double _baseline(List<BreathAcousticSample> samples) {
    if (samples.length <= calibrationSkipSamples) {
      return _minBaseline;
    }
    final calibrationSamples = samples
        .skip(calibrationSkipSamples)
        .take(calibrationSampleCount)
        .map((s) => s.rmsEnergy)
        .toList()
      ..sort();
    if (calibrationSamples.isEmpty) {
      return _minBaseline;
    }
    final median = calibrationSamples[calibrationSamples.length ~/ 2];
    return max(median, _minBaseline);
  }

  bool _isCalibrated(List<BreathAcousticSample> samples) =>
      samples.length > _calibrationSampleTotal;

  /// First timestamp at which [onsetDebounceSamples] consecutive samples
  /// exceed the adaptive onset threshold — attributed to the *first* sample
  /// of that run, not the one that confirmed it, so the reported time
  /// matches when the exhale actually started rather than when detection
  /// caught up with it.
  /// [searchFromMs] restricts which samples may *start* an exhale without
  /// changing what the noise floor is measured from. The caller needs that
  /// separation: the hold step is the only genuinely quiet stretch of an
  /// attempt (the user is holding their breath), so it makes the honest
  /// baseline — but the loud inhale that preceded it sits in the same buffer
  /// and would otherwise be picked up as an exhale onset that already
  /// happened.
  int? findExhaleOnsetMs(
    List<BreathAcousticSample> samples, {
    int? searchFromMs,
  }) {
    if (!_isCalibrated(samples)) {
      return null;
    }
    final baseline = _baseline(samples);
    final threshold = baseline * onsetMultiplier + onsetAbsoluteMargin;
    final candidates = samples
        .skip(_calibrationSampleTotal)
        .where(
          (s) => searchFromMs == null || s.millisecondsSinceStart >= searchFromMs,
        )
        .toList();

    var streak = 0;
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i].rmsEnergy > threshold) {
        streak++;
        if (streak >= onsetDebounceSamples) {
          return candidates[i - onsetDebounceSamples + 1].millisecondsSinceStart;
        }
      } else {
        streak = 0;
      }
    }
    return null;
  }

  /// First timestamp after [onsetMs] at which [offsetDebounceSamples]
  /// consecutive samples drop back below the (lower, hysteresis) offset
  /// threshold. Returns null if the exhale never clearly ends within the
  /// provided samples (caller should keep listening or fall back).
  int? findExhaleOffsetMs(List<BreathAcousticSample> samples, int onsetMs) {
    final baseline = _baseline(samples);
    final threshold = baseline * offsetMultiplier + onsetAbsoluteMargin;
    final candidates = samples
        .where((s) => s.millisecondsSinceStart > onsetMs)
        .toList();

    var streak = 0;
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i].rmsEnergy < threshold) {
        streak++;
        if (streak >= offsetDebounceSamples) {
          return candidates[i - offsetDebounceSamples + 1].millisecondsSinceStart;
        }
      } else {
        streak = 0;
      }
    }
    return null;
  }

  /// Full post-hoc analysis once an attempt's samples are complete (either
  /// because offset was auto-detected, or the user manually stopped and
  /// whatever was captured up to that point is passed in). Returns
  /// `exhaleDetected: false` — caller falls back to the timing-based proxy
  /// — whenever onset/offset couldn't be confidently established.
  BreathAcousticAnalysis analyze(List<BreathAcousticSample> samples) {
    if (samples.isEmpty) {
      return const BreathAcousticAnalysis(exhaleDetected: false);
    }

    final onsetMs = findExhaleOnsetMs(samples);
    if (onsetMs == null) {
      return const BreathAcousticAnalysis(exhaleDetected: false);
    }

    final offsetMs = findExhaleOffsetMs(samples, onsetMs);
    if (offsetMs == null) {
      return const BreathAcousticAnalysis(exhaleDetected: false);
    }

    final exhaleSamples = samples
        .where(
          (s) =>
              s.millisecondsSinceStart >= onsetMs &&
              s.millisecondsSinceStart <= offsetMs,
        )
        .toList();
    if (exhaleSamples.isEmpty) {
      return const BreathAcousticAnalysis(exhaleDetected: false);
    }

    final energies = exhaleSamples.map((s) => s.rmsEnergy).toList();
    final mean = energies.reduce((a, b) => a + b) / energies.length;
    final variance =
        energies.map((e) => pow(e - mean, 2).toDouble()).reduce((a, b) => a + b) /
        energies.length;
    final stdDev = sqrt(variance);

    // Coefficient-of-variation based, so it needs no arbitrary "loud blow"
    // reference constant — a steady exhale has low relative spread
    // regardless of how loud the microphone happened to pick it up.
    final stability = mean <= 0
        ? 0.0
        : (1 - (stdDev / mean)).clamp(0.0, 1.0).toDouble();

    // Intensity does need a reference point (there's no way around it —
    // "loud" is only meaningful relative to something). Chosen
    // conservatively from typical close-mic exhale RMS levels; deliberately
    // documented as approximate rather than clinically calibrated.
    const referenceLoudExhaleEnergy = 0.25;
    final intensity = (mean / referenceLoudExhaleEnergy).clamp(0.0, 1.0).toDouble();

    return BreathAcousticAnalysis(
      exhaleDetected: true,
      holdDurationMs: onsetMs,
      blowDurationMs: offsetMs - onsetMs,
      blowIntensity: intensity,
      blowStability: stability,
    );
  }
}
