import 'dart:math';

import '../models/breath_acoustic_sample.dart';

/// One detected cough — the midpoint timestamp of the energy burst and its
/// peak energy relative to the recording's own noise floor.
class CoughEvent {
  final int millisecondsSinceStart;
  final double peakEnergy;

  const CoughEvent({
    required this.millisecondsSinceStart,
    required this.peakEnergy,
  });
}

class CoughTestAnalysis {
  final int coughCount;
  final int severityScore;
  final String severityLevel;
  final double? averageIntervalSeconds;
  final double? earlyBurstRatio;
  final int? peakIntensityScore;

  /// True when the recording itself looks unusable — every sample at or
  /// near zero energy, consistent with a microphone that never actually
  /// opened (backgrounded app, OS-denied permission mid-test, muted input)
  /// rather than a genuinely quiet room. A real room, even silent, still
  /// carries measurable electronic/ambient noise-floor energy; a recording
  /// that never does is a signal-quality failure, not a clean result, and
  /// should not be shown as "normal" — see [severityLevel]'s own
  /// zero-coughs-reads-as-normal behavior, which this flag exists to catch
  /// before the caller trusts it.
  final bool insufficientSignal;

  const CoughTestAnalysis({
    required this.coughCount,
    required this.severityScore,
    required this.severityLevel,
    this.averageIntervalSeconds,
    this.earlyBurstRatio,
    this.peakIntensityScore,
    this.insufficientSignal = false,
  });
}

/// Counts distinct cough events in a short (default 30s), user-initiated
/// recording and derives simple pattern metrics from them.
///
/// Pure rule-based DSP (median-adaptive threshold + debounce), the same
/// family of technique as [BreathAcousticEngine] and the native overnight
/// snoring probe (SleepProbeReceiver.kt:detectSnorePattern) — no
/// periodicity check here, unlike snoring, since a cough test only needs to
/// count discrete events, not judge whether they repeat at a steady
/// interval. Deliberately no machine learning, matching the rest of the
/// app's fully offline, deterministic, explainable engines.
///
/// DSP constants below are a starting estimate, not device-verified —
/// coughs are short, sharp energy bursts (roughly 150-350ms) compared to
/// snoring's longer, slower cycle, so the debounce window is much tighter
/// than SleepProbeReceiver's. These should be revisited against real
/// recordings before shipping.
class CoughAcousticEngine {
  /// Multiplier applied to the median sample energy to set the event
  /// threshold — mirrors detectSnorePattern's `median * 2.0 + epsilon`.
  static const double thresholdMultiplier = 2.0;
  static const double thresholdAbsoluteMargin = 0.01;

  /// Minimum gap between two samples for them to count as separate cough
  /// events rather than the same burst — coughs are short, so this is a
  /// small fraction of the snoring probe's 200ms debounce window.
  static const int minEventGapMs = 120;

  static const int defaultTestDurationSeconds = 30;

  /// Same floor [analyze] already uses as `baseline`'s minimum — below
  /// this, a sample's energy is indistinguishable from a microphone
  /// capturing nothing at all rather than genuine (even very quiet) audio.
  static const double minPlausibleEnergy = 0.002;

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Finds distinct cough events from a stream of energy samples. Samples
  /// above the adaptive threshold are grouped: consecutive above-threshold
  /// samples are one event, and a new event only starts once
  /// [minEventGapMs] has passed since the last event's peak — this
  /// collapses a single cough's multi-sample energy burst into one count
  /// instead of several.
  List<CoughEvent> findCoughEvents(List<BreathAcousticSample> samples) {
    if (samples.isEmpty) {
      return const [];
    }
    final energies = samples.map((s) => s.rmsEnergy).toList();
    final threshold =
        _median(energies) * thresholdMultiplier + thresholdAbsoluteMargin;

    final events = <CoughEvent>[];
    int? burstStartIndex;
    double burstPeakEnergy = 0;
    int burstPeakMs = 0;

    void closeBurst() {
      if (burstStartIndex == null) return;
      final lastEvent = events.isNotEmpty ? events.last : null;
      if (lastEvent == null ||
          burstPeakMs - lastEvent.millisecondsSinceStart >= minEventGapMs) {
        events.add(
          CoughEvent(
            millisecondsSinceStart: burstPeakMs,
            peakEnergy: burstPeakEnergy,
          ),
        );
      }
      burstStartIndex = null;
      burstPeakEnergy = 0;
    }

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      if (sample.rmsEnergy > threshold) {
        burstStartIndex ??= i;
        if (sample.rmsEnergy > burstPeakEnergy) {
          burstPeakEnergy = sample.rmsEnergy;
          burstPeakMs = sample.millisecondsSinceStart;
        }
      } else {
        closeBurst();
      }
    }
    closeBurst();

    return events;
  }

  int severityScore(int coughCount, int testDurationSeconds) {
    // Normalized to a 30s window so a longer/shorter test duration doesn't
    // silently change what counts as "severe".
    final scaled = testDurationSeconds <= 0
        ? coughCount.toDouble()
        : coughCount * (defaultTestDurationSeconds / testDurationSeconds);
    if (scaled <= 0) return 0;
    if (scaled <= 2) return 30;
    if (scaled <= 5) return 55;
    if (scaled <= 9) return 80;
    return 92;
  }

  String severityLevel(int severityScore) {
    if (severityScore < 25) return 'normal';
    if (severityScore < 50) return 'mild';
    if (severityScore < 75) return 'moderate';
    return 'severe';
  }

  /// Full analysis for a completed test: count, severity, and pattern
  /// metrics (average gap between coughs, how front-loaded the burst was,
  /// and the loudest single cough's relative intensity). The pattern
  /// metrics are null when there's nothing to compute them from — zero or
  /// one detected cough.
  CoughTestAnalysis analyze(
    List<BreathAcousticSample> samples, {
    int testDurationSeconds = defaultTestDurationSeconds,
  }) {
    // Checked before anything else: a recording whose loudest moment never
    // clears the noise floor didn't fail to capture a cough, it failed to
    // capture anything — findCoughEvents would return zero events either
    // way, which severityLevel alone reads as a clean "normal" result.
    final insufficientSignal =
        samples.isEmpty ||
        samples.every((s) => s.rmsEnergy < minPlausibleEnergy);
    if (insufficientSignal) {
      return const CoughTestAnalysis(
        coughCount: 0,
        severityScore: 0,
        severityLevel: 'normal',
        insufficientSignal: true,
      );
    }

    final events = findCoughEvents(samples);
    final count = events.length;
    final score = severityScore(count, testDurationSeconds);
    final level = severityLevel(score);

    double? averageInterval;
    if (count >= 2) {
      final totalSpanMs =
          events.last.millisecondsSinceStart -
          events.first.millisecondsSinceStart;
      averageInterval = (totalSpanMs / (count - 1)) / 1000.0;
    }

    double? earlyBurstRatio;
    int? peakIntensity;
    if (count >= 1) {
      final testDurationMs = testDurationSeconds * 1000;
      final earlyWindowEndMs = testDurationMs / 3;
      final earlyCount = events
          .where((e) => e.millisecondsSinceStart <= earlyWindowEndMs)
          .length;
      earlyBurstRatio = earlyCount / count;

      final medianEnergy = _median(samples.map((s) => s.rmsEnergy).toList());
      final baseline = max(medianEnergy, minPlausibleEnergy);
      // Log-scaled: the raw energy ratio between a loud cough and a quiet
      // room can span two-plus orders of magnitude, which would saturate a
      // linear scale at 100 for almost any real cough. log2 keeps the
      // 0-100 range meaningfully spread across that whole span instead.
      final peakEnergy = events.map((e) => e.peakEnergy).reduce(max);
      final ratio = max(peakEnergy / baseline, 1.0);
      peakIntensity = ((log(ratio) / ln2) * 12).clamp(0, 100).round();
    }

    return CoughTestAnalysis(
      coughCount: count,
      severityScore: score,
      severityLevel: level,
      averageIntervalSeconds: averageInterval,
      earlyBurstRatio: earlyBurstRatio,
      peakIntensityScore: peakIntensity,
    );
  }
}
