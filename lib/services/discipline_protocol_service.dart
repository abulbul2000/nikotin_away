import 'dart:math';

import '../models/adaptive_task_models.dart';
import '../models/sensor_usage_event.dart';

class DisciplineProtocolService {
  final Random _random;

  DisciplineProtocolService({Random? random}) : _random = random ?? Random();

  static const int _minDurationBarrierMinutes = 30;
  static const int _multiDayTierFloorMinutes = 2 * 24 * 60;

  /// Duration-barrier escalation tiers, in minutes. Each tier requires more
  /// earned trust (difficultyLevel only rises with sustained real task
  /// success — see [evolveStateFromOutcome] — and successStreak resets to 0
  /// on any deferred/smoked outcome) than the last, so a user can't reach
  /// "don't smoke for a week" without weeks of consistent success behind
  /// them; a single relapse drops the streak-gated top tiers immediately.
  /// Returns (minMinutes, maxMinutes) — equal values mean a fixed duration
  /// (no jitter), used for the top "this month" tier.
  (int, int) resolveDurationTierRange(AdaptiveTaskState state) {
    final level = state.difficultyLevel;
    final streak = state.successStreak;
    if (level >= 9.5 && streak >= 21) {
      return (30 * 24 * 60, 30 * 24 * 60); // "Bu ay sigara içme"
    }
    if (level >= 9 && streak >= 10) {
      return (_multiDayTierFloorMinutes, 7 * 24 * 60); // 2-7 gün
    }
    if (level >= 7.5) {
      return (12 * 60, 24 * 60); // 12-24 saat
    }
    if (level >= 6) {
      return (4 * 60, 8 * 60); // 4-8 saat
    }
    if (level >= 3.5) {
      return (60, 3 * 60); // 1-3 saat
    }
    return (_minDurationBarrierMinutes, 60); // Baslangic: 30-60 dk
  }

  double computeSuccessRate({
    required int successCount,
    required int failureCount,
  }) {
    final total = successCount + failureCount;
    if (total <= 0) {
      return 0.0;
    }
    return successCount / total;
  }

  Duration computeAdaptiveTaskDuration({
    required Duration baseDuration,
    required double successRate,
  }) {
    var extraMinutes = 0;
    if (successRate >= 0.85) {
      extraMinutes = 20;
    } else if (successRate >= 0.7) {
      extraMinutes = 12;
    } else if (successRate >= 0.55) {
      extraMinutes = 6;
    }

    return baseDuration + Duration(minutes: extraMinutes);
  }

  Duration computeUnpredictableDelay({
    required Duration baseDelay,
    required double successRate,
    int minMinutes = 3,
  }) {
    final baseMinutes = baseDelay.inMinutes <= 0 ? 1 : baseDelay.inMinutes;

    // Shorten intervals as success rises to keep the protocol demanding.
    final compressionFactor = successRate >= 0.85
        ? 0.55
        : successRate >= 0.7
        ? 0.65
        : successRate >= 0.55
        ? 0.8
        : 1.0;
    final compressed = max(minMinutes, (baseMinutes * compressionFactor).round());

    // Add larger jitter at higher success levels for unpredictability.
    final jitterRange = successRate >= 0.85
        ? 16
        : successRate >= 0.7
        ? 12
        : successRate >= 0.55
        ? 8
        : 5;
    final jitter = _random.nextInt((jitterRange * 2) + 1) - jitterRange;
    final finalMinutes = max(minMinutes, compressed + jitter);

    return Duration(minutes: finalMinutes);
  }

  // Without a floor here, two independently-sampled candidates could land
  // minutes (or even seconds) apart — "unpredictable" was never meant to
  // include "back-to-back", just not on a fixed schedule the user could
  // learn to anticipate.
  static const int _minMomentGapMinutes = 45;

  List<DateTime> generateUnpredictableMoments({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
    required int minCount,
    required double successRate,
  }) {
    final results = <DateTime>[];
    final seen = <String>{};
    final windows = _resolveCandidateWindows(
      now: now,
      sleepAt: sleepAt,
      riskyHours: riskyHours,
    );

    if (windows.isEmpty) {
      return results;
    }

    final bonus = successRate >= 0.85
        ? 3
        : successRate >= 0.7
        ? 2
        : successRate >= 0.55
        ? 1
        : 0;
    final targetCount = minCount + bonus;

    var guard = 0;
    while (results.length < targetCount && guard < 250) {
      guard += 1;
      final window = windows[_random.nextInt(windows.length)];
      final start = window.$1;
      final end = window.$2;
      if (!end.isAfter(start)) {
        continue;
      }

      final maxMinutes = end.difference(start).inMinutes;
      if (maxMinutes <= 1) {
        continue;
      }
      final minuteOffset = _random.nextInt(maxMinutes);
      final candidate = start.add(Duration(minutes: minuteOffset));
      if (!candidate.isAfter(now) || !candidate.isBefore(sleepAt)) {
        continue;
      }

      final tooCloseToExisting = results.any(
        (existing) =>
            candidate.difference(existing).abs().inMinutes <
            _minMomentGapMinutes,
      );
      if (tooCloseToExisting) {
        continue;
      }

      final key =
          '${candidate.year}-${candidate.month}-${candidate.day}-${candidate.hour}-${candidate.minute}';
      if (seen.add(key)) {
        results.add(candidate);
      }
    }

    results.sort((a, b) => a.compareTo(b));
    return results;
  }

  bool isSuspiciousDuringTask({
    required List<SensorUsageEvent> events,
    required List<String> riskyHours,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (events.isEmpty || !endAt.isAfter(startAt)) {
      return false;
    }

    for (final event in events) {
      if (event.createdAt.isBefore(startAt) || event.createdAt.isAfter(endAt)) {
        continue;
      }

      final riskyWindowActive = _isHourInRiskWindow(event.createdAt.hour, riskyHours);
      final intenseMotion =
          event.accelerometerMagnitude >= 1.8 || event.gyroscopeMagnitude >= 1.8;
      final phoneSpike =
          event.screenUnlockCount >= 12 || event.appUsageMinutes >= 20;
      final nonIdle = event.activityState.toLowerCase().trim() != 'idle';

      if ((intenseMotion || phoneSpike) && (riskyWindowActive || nonIdle)) {
        return true;
      }
    }

    return false;
  }

  List<(DateTime, DateTime)> _resolveCandidateWindows({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
  }) {
    final windows = <(DateTime, DateTime)>[];

    for (final raw in riskyHours) {
      final range = _parseHourRange(now: now, raw: raw);
      if (range == null) {
        continue;
      }
      var start = range.$1;
      var end = range.$2;

      if (end.isBefore(now)) {
        start = start.add(const Duration(days: 1));
        end = end.add(const Duration(days: 1));
      }

      if (start.isBefore(sleepAt) && end.isAfter(now)) {
        final clampedStart = start.isBefore(now) ? now : start;
        final clampedEnd = end.isAfter(sleepAt) ? sleepAt : end;
        if (clampedEnd.isAfter(clampedStart)) {
          windows.add((clampedStart, clampedEnd));
        }
      }
    }

    if (windows.isEmpty) {
      var cursor = now.add(const Duration(minutes: 8));
      while (cursor.isBefore(sleepAt) && windows.length < 6) {
        final end = cursor.add(const Duration(minutes: 40));
        windows.add((cursor, end.isAfter(sleepAt) ? sleepAt : end));
        cursor = cursor.add(const Duration(minutes: 55));
      }
    }

    return windows;
  }

  (DateTime, DateTime)? _parseHourRange({
    required DateTime now,
    required String raw,
  }) {
    final value = raw.trim();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*-\s*(\d{1,2})(?::(\d{2}))?')
        .firstMatch(value);
    if (match == null) {
      return null;
    }

    final startHour = int.tryParse(match.group(1) ?? '');
    final startMinute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final endHour = int.tryParse(match.group(3) ?? '');
    final endMinute = int.tryParse(match.group(4) ?? '0') ?? 0;
    if (startHour == null || endHour == null) {
      return null;
    }

    var start = DateTime(
      now.year,
      now.month,
      now.day,
      startHour.clamp(0, 23),
      startMinute.clamp(0, 59),
    );
    var end = DateTime(
      now.year,
      now.month,
      now.day,
      endHour.clamp(0, 23),
      endMinute.clamp(0, 59),
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return (start, end);
  }

  bool _isHourInRiskWindow(int hour, List<String> riskyHours) {
    for (final raw in riskyHours) {
      final match = RegExp(r'(\d{1,2})(?::\d{2})?\s*-\s*(\d{1,2})(?::\d{2})?')
          .firstMatch(raw.trim());
      if (match == null) {
        continue;
      }

      final start = int.tryParse(match.group(1) ?? '');
      final end = int.tryParse(match.group(2) ?? '');
      if (start == null || end == null) {
        continue;
      }

      if (start <= end) {
        if (hour >= start && hour < end) {
          return true;
        }
      } else {
        if (hour >= start || hour < end) {
          return true;
        }
      }
    }
    return false;
  }

  AdaptiveTaskPlan buildDailyAdaptivePlan({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
    required AdaptiveTaskState state,
    required List<AdaptiveHourlyProfileEntry> hourlyProfiles,
    int baselineTaskCount = 5,
  }) {
    final successRate = state.movingSuccessRate.clamp(0, 1);
    final failureRate = state.movingFailureRate.clamp(0, 1);
    final postponeRate = state.postponeRate.clamp(0, 1);

    var targetTaskCount = baselineTaskCount;
    if (successRate >= 0.75) {
      targetTaskCount += 1;
    }
    if (successRate >= 0.88) {
      targetTaskCount += 1;
    }
    if (failureRate >= 0.45) {
      targetTaskCount -= 1;
    }
    if (postponeRate >= 0.5) {
      targetTaskCount -= 1;
    }

    targetTaskCount += _random.nextInt(3) - 1;
    targetTaskCount = targetTaskCount.clamp(3, 9);

    final tierRange = resolveDurationTierRange(state);
    var baseDurationMinutes = tierRange.$1 == tierRange.$2
        ? tierRange.$1
        : tierRange.$1 + _random.nextInt(tierRange.$2 - tierRange.$1 + 1);

    // The top two tiers (multi-day / "this month") are a single standing
    // commitment, not several same-day reminders — generating a handful of
    // independent multi-day barriers in one day's plan wouldn't mean
    // anything. Once a user has earned one of those tiers, today's plan
    // collapses to exactly that one commitment instead of the usual spread.
    if (tierRange.$1 >= _multiDayTierFloorMinutes) {
      targetTaskCount = 1;
    }

    final moments = generateUnpredictableMoments(
      now: now,
      sleepAt: sleepAt,
      riskyHours: riskyHours,
      minCount: targetTaskCount,
      successRate: successRate.toDouble(),
    );

    final items = <AdaptiveTaskPlanItem>[];
    for (var i = 0; i < targetTaskCount; i++) {
      final scheduledAt = i < moments.length
          ? moments[i]
          : now.add(Duration(minutes: 20 + (i * 35) + _random.nextInt(20)));
      final hourEntry = _findProfileEntry(
        hour: scheduledAt.hour,
        hourlyProfiles: hourlyProfiles,
      );

      int duration;
      if (tierRange.$1 >= _multiDayTierFloorMinutes) {
        // A single standing commitment (multi-day / "this month") — no
        // per-task jitter or within-day escalation, those only make sense
        // for the same-day minute/hour-scale tiers below.
        duration = baseDurationMinutes;
      } else {
        final strainOffset = hourEntry == null
            ? 0
            : (hourEntry.strainScore >= 70
                  ? -2
                  : hourEntry.strainScore <= 35
                  ? 2
                  : 0);
        final progressiveStep = i == 0
            ? 0
            : (2 + (state.difficultyLevel / 3).floor());
        duration =
            (baseDurationMinutes +
                    (progressiveStep * i) +
                    strainOffset +
                    (_random.nextInt(5) - 2))
                .clamp(_minDurationBarrierMinutes, tierRange.$2)
                .toInt();
      }

      items.add(
        AdaptiveTaskPlanItem(
          scheduledAt: scheduledAt,
          durationMinutes: duration,
          taskTitle: 'ADAPTIVE_NO_SMOKE:$duration',
        ),
      );
    }

    return AdaptiveTaskPlan(
      targetTaskCount: targetTaskCount,
      baseDurationMinutes: baseDurationMinutes,
      items: items,
    );
  }

  Duration computeAdaptivePostponeDelay({
    required AdaptiveTaskState state,
    int baseMinutes = 10,
  }) {
    var minutes = baseMinutes;
    if (state.postponeRate >= 0.45) {
      minutes += 4;
    }
    if (state.postponeRate >= 0.65) {
      minutes += 3;
    }
    if (state.movingSuccessRate >= 0.75) {
      minutes -= 1;
    }
    if (state.avgResponseMinutes >= 15) {
      minutes += 2;
    }

    minutes += _random.nextInt(7) - 2;
    return Duration(minutes: minutes.clamp(8, 25).toInt());
  }

  AdaptiveTaskState evolveStateFromOutcome({
    required AdaptiveTaskState current,
    required String outcome,
    required int responseDelayMinutes,
  }) {
    final isSuccess = outcome == AdaptiveTaskOutcome.success;
    final isDeferred = outcome == AdaptiveTaskOutcome.deferred;
    final isSmoked = outcome == AdaptiveTaskOutcome.smoked;
    final isMissed = outcome == AdaptiveTaskOutcome.missed;

    var selfControl = current.selfControlScore;
    var difficulty = current.difficultyLevel;
    var capacity = current.dailyTaskCapacity;
    var successStreak = current.successStreak;
    var failureStreak = current.failureStreak;

    if (isSuccess) {
      selfControl += 2.8;
      difficulty += 0.24;
      capacity += 0.10;
      successStreak += 1;
      failureStreak = 0;
    } else if (isDeferred) {
      selfControl -= 0.6;
      difficulty -= 0.03;
      capacity -= 0.02;
      successStreak = 0;
    } else if (isMissed) {
      // Between deferred (an active "not now") and smoked (an explicit
      // admission) -- 3 unanswered attempts over 15 minutes on a mandatory
      // alert is a real failure signal, but not proof the user smoked.
      selfControl -= 1.5;
      difficulty -= 0.15;
      capacity -= 0.06;
      failureStreak += 1;
      successStreak = 0;
    } else if (isSmoked) {
      selfControl -= 2.3;
      difficulty -= 0.33;
      capacity -= 0.12;
      failureStreak += 1;
      successStreak = 0;
    }

    final updated = current.copyWith(
      selfControlScore: selfControl.clamp(5, 100),
      difficultyLevel: difficulty.clamp(1, 10),
      dailyTaskCapacity: capacity.clamp(3, 9),
      postponeRate: _ewma(
        previous: current.postponeRate,
        incoming: isDeferred ? 1 : 0,
        alpha: 0.15,
      ).clamp(0, 1),
      movingSuccessRate: _ewma(
        previous: current.movingSuccessRate,
        incoming: isSuccess ? 1 : 0,
        alpha: 0.18,
      ).clamp(0, 1),
      movingFailureRate: _ewma(
        previous: current.movingFailureRate,
        incoming: (isSmoked || isMissed) ? 1 : 0,
        alpha: 0.18,
      ).clamp(0, 1),
      avgResponseMinutes: _ewma(
        previous: current.avgResponseMinutes,
        incoming: responseDelayMinutes.toDouble(),
        alpha: 0.20,
      ).clamp(1, 240),
      successStreak: successStreak,
      failureStreak: failureStreak,
      updatedAt: DateTime.now(),
    );

    return updated;
  }

  AdaptiveHourlyProfileEntry evolveHourlyProfileFromOutcome({
    required AdaptiveHourlyProfileEntry current,
    required String outcome,
    required int responseDelayMinutes,
  }) {
    final isSuccess = outcome == AdaptiveTaskOutcome.success;
    final isDeferred = outcome == AdaptiveTaskOutcome.deferred;
    final isSmoked = outcome == AdaptiveTaskOutcome.smoked;
    final isMissed = outcome == AdaptiveTaskOutcome.missed;

    final strainDelta = isSuccess
        ? -0.45
        : isDeferred
        ? 0.30
        : isMissed
        ? 0.6
        : isSmoked
        ? 0.85
        : 0.0;

    return current.copyWith(
      strainScore: (current.strainScore + strainDelta).clamp(0, 100),
      successCount: current.successCount + (isSuccess ? 1 : 0),
      failureCount: current.failureCount + ((isSmoked || isMissed) ? 1 : 0),
      deferCount: current.deferCount + (isDeferred ? 1 : 0),
      avgResponseMinutes: _ewma(
        previous: current.avgResponseMinutes,
        incoming: responseDelayMinutes.toDouble(),
        alpha: 0.20,
      ).clamp(1, 240),
      updatedAt: DateTime.now(),
    );
  }

  AdaptiveHourlyProfileEntry? _findProfileEntry({
    required int hour,
    required List<AdaptiveHourlyProfileEntry> hourlyProfiles,
  }) {
    for (final entry in hourlyProfiles) {
      if (entry.hour == hour) {
        return entry;
      }
    }
    return null;
  }

  double _ewma({
    required double previous,
    required double incoming,
    required double alpha,
  }) {
    return (previous * (1 - alpha)) + (incoming * alpha);
  }
}