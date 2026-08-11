import 'dart:math';

import '../models/breath_acoustic_sample.dart';

class SnoringAnalysis {
  /// Whether a rhythmic, snore-typical loud/quiet pattern was found.
  final bool snoreLikely;

  /// 'none' | 'mild' | 'moderate' | 'severe'.
  final String severityLevel;

  /// 0-100, same shape as WheezeAnalysis.severityScore.
  final int severityScore;

  /// How many loud "bursts" were found in the clip, regardless of whether
  /// they ended up snore-cycle-spaced — a plain diagnostic count.
  final int eventCount;

  const SnoringAnalysis({
    required this.snoreLikely,
    required this.severityLevel,
    required this.severityScore,
    required this.eventCount,
  });

  static const none = SnoringAnalysis(
    snoreLikely: false,
    severityLevel: 'none',
    severityScore: 0,
    eventCount: 0,
  );
}

/// Dart-side counterpart to SleepProbeReceiver.kt's `detectSnoreSeverity` —
/// same heuristic (energy-envelope bursts + snore-cycle periodicity +
/// intensity/continuity severity scoring), reimplemented here so the
/// user-initiated, daytime Snoring Test (run through BreathAudioService
/// while the Flutter engine is alive) doesn't need a platform channel round
/// trip into the native overnight-probe code path, which is designed to run
/// without the app open at all.
///
/// The two implementations are kept deliberately in sync constant-for-
/// constant; if one heuristic changes, the other should too.
///
/// **Not device-calibrated** — same caveat as every other acoustic engine
/// in this app (BreathAcousticEngine, CoughAcousticEngine,
/// WheezeDetectionEngine): thresholds are derived from general DSP
/// reasoning, not validated against real snoring recordings on real device
/// hardware.
class SnoringAcousticEngine {
  /// Samples are regrouped into fixed 100ms windows before analysis — the
  /// same window size the native probe uses — since BreathAudioService's
  /// samples arrive at whatever cadence the `record` package's stream
  /// delivers chunks, not aligned to a fixed interval.
  static const int windowMs = 100;

  static const double _thresholdMultiplier = 2.0;
  static const double _thresholdFloor = 0.01;
  static const int _minEventGapWindows = 2;
  static const int snoreMinCycleMs = 300;
  static const int snoreMaxCycleMs = 1500;

  SnoringAnalysis analyze(List<BreathAcousticSample> samples) {
    if (samples.isEmpty) {
      return SnoringAnalysis.none;
    }

    final energies = _resampleToFixedWindows(samples);
    if (energies.isEmpty) {
      return SnoringAnalysis.none;
    }

    final sorted = List<double>.of(energies)..sort();
    final median = sorted[sorted.length ~/ 2];
    final threshold = median * _thresholdMultiplier + _thresholdFloor;

    final events = <int>[];
    var lastEventIndex = -10;
    for (var i = 0; i < energies.length; i++) {
      if (energies[i] > threshold && i - lastEventIndex > _minEventGapWindows) {
        events.add(i);
        lastEventIndex = i;
      }
    }
    if (events.length < 2) {
      return SnoringAnalysis(
        snoreLikely: false,
        severityLevel: 'none',
        severityScore: 0,
        eventCount: events.length,
      );
    }

    var inCycleGapCount = 0;
    for (var i = 1; i < events.length; i++) {
      final gapMs = (events[i] - events[i - 1]) * windowMs;
      if (gapMs >= snoreMinCycleMs && gapMs <= snoreMaxCycleMs) {
        inCycleGapCount++;
      }
    }

    if (inCycleGapCount == 0) {
      return SnoringAnalysis(
        snoreLikely: false,
        severityLevel: 'none',
        severityScore: 0,
        eventCount: events.length,
      );
    }

    var intensityRatioSum = 0.0;
    for (final index in events) {
      intensityRatioSum += energies[index] / threshold;
    }

    final continuityScore = (inCycleGapCount / (events.length - 1)).clamp(
      0.0,
      1.0,
    );
    final averageIntensityRatio = intensityRatioSum / events.length;
    final intensityScore = ((averageIntensityRatio - 1.0) / 1.0).clamp(
      0.0,
      1.0,
    );

    final combined = intensityScore * 0.5 + continuityScore * 0.5;
    final score = (combined * 100).round().clamp(0, 100);
    final level = _severityLevel(score);

    return SnoringAnalysis(
      snoreLikely: true,
      severityLevel: level,
      severityScore: score,
      eventCount: events.length,
    );
  }

  String _severityLevel(int score) {
    if (score <= 0) return 'none';
    if (score < 35) return 'mild';
    if (score < 65) return 'moderate';
    return 'severe';
  }

  /// Buckets samples by their timestamp into windowMs-wide slots and takes
  /// the max energy within each slot (max, not mean, so a brief loud burst
  /// inside a slot isn't diluted by quieter neighbors landing in the same
  /// window) — the closest Dart-side equivalent of the native probe's fixed
  /// 100ms AudioRecord reads. Empty slots (no sample arrived in that
  /// window) are left at 0, same as a genuinely quiet window would read.
  List<double> _resampleToFixedWindows(List<BreathAcousticSample> samples) {
    final lastMs = samples.last.millisecondsSinceStart;
    final windowCount = (lastMs / windowMs).ceil() + 1;
    if (windowCount <= 0) {
      return const [];
    }
    final energies = List<double>.filled(windowCount, 0.0);
    for (final sample in samples) {
      final index = (sample.millisecondsSinceStart / windowMs).floor().clamp(
        0,
        windowCount - 1,
      );
      energies[index] = max(energies[index], sample.rmsEnergy);
    }
    return energies;
  }
}
