/// Turns raw Health Connect heart-rate samples into a simple elevated/not
/// signal. Pure and DB-free like the other engines (StepTrendEngine,
/// SleepIntelligenceEngine, BreathAcousticEngine) — no Health Connect I/O
/// here, only arithmetic over numbers the caller already fetched.
class WearableSignalEngine {
  /// Median of the day's own heart-rate readings — a personal baseline
  /// that adapts to the individual rather than a fixed "normal" range.
  double? computeBaselineBpm(List<double> samples) {
    if (samples.isEmpty) {
      return null;
    }
    final sorted = [...samples]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// True only when the latest reading clears both a relative threshold
  /// (guards against a raised-but-still-normal reading) and an absolute
  /// minimum delta (guards against a low baseline making a tiny bpm bump
  /// look like a large ratio jump).
  bool isElevatedHeartRate({
    required double latestBpm,
    required double baselineBpm,
    double thresholdRatio = 1.25,
    double minimumDeltaBpm = 15,
  }) {
    if (baselineBpm <= 0 || latestBpm <= 0) {
      return false;
    }
    final ratio = latestBpm / baselineBpm;
    final delta = latestBpm - baselineBpm;
    return ratio >= thresholdRatio && delta >= minimumDeltaBpm;
  }
}
