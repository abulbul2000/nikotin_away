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

    if (coverage < minCoverageForTrust) {
      return SleepEstimate(
        sleepTime: fallbackSleepTime,
        wakeTime: fallbackWakeTime,
        estimated: false,
        coverage: coverage,
      );
    }

    final sorted = [...probes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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

  int _expectedProbeCount(
    int windowStartMinute,
    int windowEndMinute,
    int intervalMinutes,
  ) {
    if (intervalMinutes <= 0) {
      return 0;
    }
    final span = windowEndMinute >= windowStartMinute
        ? windowEndMinute - windowStartMinute
        : (24 * 60 - windowStartMinute) + windowEndMinute;
    return (span / intervalMinutes).floor() + 1;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
