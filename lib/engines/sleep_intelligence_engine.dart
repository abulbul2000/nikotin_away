import '../models/sleep_probe_event.dart';

class SleepEstimate {
  final String sleepTime;
  final String wakeTime;
  final bool estimated;
  final double coverage;

  const SleepEstimate({
    required this.sleepTime,
    required this.wakeTime,
    required this.estimated,
    required this.coverage,
  });
}

/// Turns a night's worth of [SleepProbeEvent] rows (screen-interactive +
/// charging state, sampled every `intervalMinutes` by the native
/// SleepProbeReceiver) into an estimated sleep window. Requires at least
/// [minCoverageForTrust] of the expected probes to be present before
/// trusting the result — per the passive-sleep-estimation research this
/// roadmap is based on, sparse coverage (app killed, device off, feature
/// just enabled) produces an unreliable window, so callers should fall back
/// to the user's static survey sleep time instead of estimating from noise.
class SleepIntelligenceEngine {
  static const double minCoverageForTrust = 0.6;

  /// A gap between two consecutive probes wider than this multiple of the
  /// configured interval is treated as a real outage (app killed, device
  /// off, probing not yet re-armed after boot) rather than an ordinary
  /// missed beat.
  static const double maxGapMultiplierForTrust = 3.0;

  /// The probes actually received must span at least this fraction of the
  /// configured window's total duration. Probes.length / expectedCount
  /// alone can't tell a night with even spacing apart from a tight burst
  /// followed by a multi-hour silent stretch — a handful of probes fired
  /// close together (e.g. a few app restarts right after falling asleep,
  /// each firing a catch-up burst) can clear [minCoverageForTrust] on raw
  /// count alone while covering only a small slice of real time, which
  /// would let the "longest screen-off run" below confidently report that
  /// slice as the whole night's sleep. Combined with [maxGapMultiplierForTrust]
  /// (no single gap too wide) this also catches the case count-and-gap
  /// checks alone would miss: many small, evenly-spaced gaps that together
  /// still leave large stretches of the window unaccounted for.
  static const double minTemporalSpanFractionForTrust = 0.6;

  SleepEstimate estimateSleepWindow({
    required List<SleepProbeEvent> probes,
    required int windowStartMinute,
    required int windowEndMinute,
    required int intervalMinutes,
    required String fallbackSleepTime,
    required String fallbackWakeTime,
  }) {
    final expectedCount = _expectedProbeCount(
      windowStartMinute,
      windowEndMinute,
      intervalMinutes,
    );
    final coverage = expectedCount == 0
        ? 0.0
        : (probes.length / expectedCount).clamp(0.0, 1.0);

    final sorted = [...probes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final expectedSpanMinutes = _expectedSpanMinutes(
      windowStartMinute,
      windowEndMinute,
    );
    final hasReliableSpan = _hasReliableTemporalSpan(
      sorted,
      expectedSpanMinutes: expectedSpanMinutes,
    );
    final hasNoLargeGaps = _hasNoLargeGaps(
      sorted,
      intervalMinutes: intervalMinutes,
    );

    if (coverage < minCoverageForTrust || !hasReliableSpan || !hasNoLargeGaps) {
      return SleepEstimate(
        sleepTime: fallbackSleepTime,
        wakeTime: fallbackWakeTime,
        estimated: false,
        coverage: coverage,
      );
    }

    var bestStart = -1;
    var bestLength = 0;
    var currentStart = -1;
    var currentLength = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].screenOff) {
        if (currentLength == 0) {
          currentStart = i;
        }
        currentLength++;
        if (currentLength > bestLength) {
          bestLength = currentLength;
          bestStart = currentStart;
        }
      } else {
        currentLength = 0;
      }
    }

    if (bestLength == 0) {
      return SleepEstimate(
        sleepTime: fallbackSleepTime,
        wakeTime: fallbackWakeTime,
        estimated: false,
        coverage: coverage,
      );
    }

    final sleepAt = sorted[bestStart].createdAt;
    final firstAwakeIndex = bestStart + bestLength;
    final wakeAt = firstAwakeIndex < sorted.length
        ? sorted[firstAwakeIndex].createdAt
        : sorted[bestStart + bestLength - 1].createdAt;

    return SleepEstimate(
      sleepTime: _formatTime(sleepAt),
      wakeTime: _formatTime(wakeAt),
      estimated: true,
      coverage: coverage,
    );
  }

  /// True when no gap between consecutive [sortedProbes] exceeds
  /// [maxGapMultiplierForTrust] times [intervalMinutes] — i.e. probing was
  /// never silent for an outage-length stretch. Trivially true for 0 or 1
  /// probes (nothing to have a gap between); that case is still correctly
  /// rejected separately by the coverage check.
  bool _hasNoLargeGaps(
    List<SleepProbeEvent> sortedProbes, {
    required int intervalMinutes,
  }) {
    if (intervalMinutes <= 0 || sortedProbes.length < 2) {
      return true;
    }
    final maxAllowedGap = Duration(
      minutes: (intervalMinutes * maxGapMultiplierForTrust).round(),
    );
    for (var i = 1; i < sortedProbes.length; i++) {
      final gap = sortedProbes[i].createdAt.difference(
        sortedProbes[i - 1].createdAt,
      );
      if (gap > maxAllowedGap) {
        return false;
      }
    }
    return true;
  }

  /// True when the actual first-to-last probe span covers at least
  /// [minTemporalSpanFractionForTrust] of [expectedSpanMinutes]. Trivially
  /// true for 0 or 1 probes; that case is still correctly rejected
  /// separately by the coverage check.
  bool _hasReliableTemporalSpan(
    List<SleepProbeEvent> sortedProbes, {
    required int expectedSpanMinutes,
  }) {
    if (expectedSpanMinutes <= 0 || sortedProbes.length < 2) {
      return true;
    }
    final actualSpanMinutes = sortedProbes.last.createdAt
        .difference(sortedProbes.first.createdAt)
        .inMinutes;
    return actualSpanMinutes >=
        expectedSpanMinutes * minTemporalSpanFractionForTrust;
  }

  int _expectedSpanMinutes(int windowStartMinute, int windowEndMinute) {
    return windowEndMinute >= windowStartMinute
        ? windowEndMinute - windowStartMinute
        : (24 * 60 - windowStartMinute) + windowEndMinute;
  }

  int _expectedProbeCount(
    int windowStartMinute,
    int windowEndMinute,
    int intervalMinutes,
  ) {
    if (intervalMinutes <= 0) {
      return 0;
    }
    final span = _expectedSpanMinutes(windowStartMinute, windowEndMinute);
    return (span / intervalMinutes).floor() + 1;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
