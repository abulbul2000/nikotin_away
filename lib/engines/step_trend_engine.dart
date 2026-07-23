import '../models/step_counter_sample.dart';

class DailyStepCount {
  final DateTime date;
  final int steps;

  const DailyStepCount({required this.date, required this.steps});
}

/// Turns raw cumulative step-counter samples (monotonic since last reboot,
/// resets to 0 on reboot) into per-day step counts. Pure and DB-free like
/// the other engines.
class StepTrendEngine {
  /// Attributes the delta between two consecutive samples to the later
  /// sample's calendar day. With the daily near-midnight probe in place,
  /// consecutive samples are normally within the same day-boundary window,
  /// so this stays accurate in the common case; a multi-day gap (feature
  /// just enabled, probes missed) degrades to a coarser approximation
  /// rather than a wrong one — acceptable for a trend, not a precise log.
  List<DailyStepCount> computeDailySteps(List<StepCounterSample> samples) {
    if (samples.length < 2) {
      return const [];
    }

    final sorted = [...samples]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final dailyTotals = <DateTime, int>{};

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      final rawDelta = current.cumulativeSteps - previous.cumulativeSteps;
      // A negative delta means the hardware counter reset (device reboot)
      // between the two samples — treat the post-reboot cumulative value
      // itself as that window's step count rather than going negative.
      final delta = rawDelta >= 0 ? rawDelta : current.cumulativeSteps;

      final day = _dateOnly(current.createdAt.toLocal());
      dailyTotals[day] = (dailyTotals[day] ?? 0) + delta;
    }

    final result = dailyTotals.entries
        .map((entry) => DailyStepCount(date: entry.key, steps: entry.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  int totalStepsInRange(
    List<StepCounterSample> samples, {
    required DateTime start,
    required DateTime end,
  }) {
    final daily = computeDailySteps(samples);
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    return daily
        .where(
          (day) => !day.date.isBefore(startDay) && day.date.isBefore(endDay),
        )
        .fold(0, (sum, day) => sum + day.steps);
  }

  /// 'Increasing' | 'Decreasing' | 'Stable' — matches the vocabulary
  /// `BehaviorEngine.calculateSmokingTrend` already uses elsewhere, so
  /// callers can reuse the same localized trend labels.
  String trendFor(List<DailyStepCount> dailyCounts) {
    if (dailyCounts.length < 2) {
      return 'Stable';
    }
    final first = dailyCounts.first.steps;
    final last = dailyCounts.last.steps;
    if (last > first) {
      return 'Increasing';
    }
    if (last < first) {
      return 'Decreasing';
    }
    return 'Stable';
  }

  /// True when the most recent day's step count is markedly below the
  /// average of the prior days — physical activity is well-established to
  /// reduce cravings, so a sudden drop from the user's own baseline is a
  /// small, personalized craving-risk signal (Phase 11). Requires at least
  /// 2 prior days plus the most recent one — comparing against a single
  /// prior day would be too noisy to trust.
  bool isMostRecentDaySedentary(
    List<DailyStepCount> dailyCounts, {
    double thresholdRatio = 0.4,
  }) {
    if (dailyCounts.length < 3) {
      return false;
    }
    final sorted = [...dailyCounts]..sort((a, b) => a.date.compareTo(b.date));
    final mostRecent = sorted.last;
    final priorDays = sorted.sublist(0, sorted.length - 1);
    final average =
        priorDays.fold<int>(0, (sum, day) => sum + day.steps) /
        priorDays.length;
    if (average <= 0) {
      return false;
    }
    return mostRecent.steps < average * thresholdRatio;
  }

  /// True when the earliest and latest sample in [samples] span at least
  /// [minGap] but almost no steps were taken in between — a real "sat
  /// still for a while" signal, not just "the app happened to be opened
  /// twice in quick succession" (samples are only ever written on a
  /// throttled foreground read or the daily native probe, never
  /// continuously, so a short gap between two samples says nothing about
  /// activity level either way).
  bool isSedentaryWindow(
    List<StepCounterSample> samples, {
    Duration minGap = const Duration(hours: 1, minutes: 30),
    int stepThreshold = 150,
  }) {
    if (samples.length < 2) {
      return false;
    }
    final sorted = [...samples]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first;
    final last = sorted.last;
    if (last.createdAt.difference(first.createdAt) < minGap) {
      return false;
    }
    final rawDelta = last.cumulativeSteps - first.cumulativeSteps;
    final delta = rawDelta >= 0 ? rawDelta : last.cumulativeSteps;
    return delta < stepThreshold;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
