import '../models/smoking_time_prediction.dart';
import '../models/survey_record.dart';

/// Predicts *when* during the day this user is likely to smoke, using only
/// data the app already collects — no new survey questions required:
///
/// - sleep/wake time -> zeroes out the sleep window, anchors the day's start
/// - first-cigarette-after-waking timing -> anchors the day's first peak
/// - work schedule + workplace smoking rule + break windows -> shapes the
///   daytime distribution (suppressed during "no smoking at work" hours,
///   concentrated into break windows when smoking is break-restricted)
/// - weekend pattern -> widens/narrows the distribution for non-work days
/// - (once a weekly survey exists) meal times and trigger-exposure days
///   (coffee/meal/driving/stress/phone/social/alcohol) -> extra peaks
///
/// This is a deterministic, on-device, rule-based **prior** — not a learned
/// model. It is designed to be the starting point that gets calibrated over
/// time by real logged smoking events (see the optional quick-log feature),
/// shifting trust from "what the survey implies" toward "what the user
/// actually reported" as that history accumulates. That calibration step is
/// not implemented here; this engine only produces the structural prior and
/// reports a [SmokingTimePrediction.confidence] low enough to reflect that.
class SmokingTimePredictionEngine {
  static const double _baseline = 0.15;

  SmokingTimePrediction predict({
    required Map<String, dynamic> profileContext,
    required String packsPerDay,
    bool isWeekend = false,
  }) {
    final sleepMinutes = _parseMinutes(profileContext['sleepTime']?.toString());
    final wakeMinutes = _parseMinutes(profileContext['wakeTime']?.toString());
    final workStartMinutes = _parseMinutes(
      profileContext['workStart']?.toString(),
    );
    final workEndMinutes = _parseMinutes(profileContext['workEnd']?.toString());
    final workplaceRule = (profileContext['workplaceSmokingRule']?.toString() ?? '')
        .toLowerCase();
    final weekendPattern =
        (profileContext['weekendSmokingPattern']?.toString() ?? '').toLowerCase();
    final breakWindows =
        (profileContext['breakWindows'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final firstCigaretteRange = profileContext['firstCigaretteRange']
        ?.toString();
    final weeklyPayload =
        profileContext['weeklyPayload'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final hasWeeklyData = weeklyPayload.isNotEmpty;
    final mealSchedule =
        weeklyPayload['mealSchedule'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final triggerExposureDays =
        weeklyPayload['triggerExposureDays'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    // Every hour starts with a small non-zero baseline — this is a
    // likelihood prior, not a hard rule; nothing should read as "impossible"
    // just because the structural signal is weak for that hour.
    final weights = List<double>.filled(24, _baseline);

    _zeroSleepWindow(weights, sleepMinutes, wakeMinutes);
    _boostFirstCigarette(weights, wakeMinutes, firstCigaretteRange);
    _applyWorkplaceRule(
      weights,
      workplaceRule: workplaceRule,
      workStartMinutes: workStartMinutes,
      workEndMinutes: workEndMinutes,
      breakWindows: breakWindows,
    );
    _boostMealTimes(weights, mealSchedule, triggerExposureDays);
    _boostEveningTriggers(weights, triggerExposureDays);
    _applyWeekendPattern(weights, weekendPattern, isWeekend);

    final total = weights.fold<double>(0, (sum, w) => sum + w);
    final normalized = total <= 0
        ? List<double>.filled(24, 1 / 24)
        : weights.map((w) => w / total).toList();

    final cigarettesPerPack = _toIntOrNull(profileContext['cigarettesPerPack']);
    final dailyCigarettes = cigarettesPerPack != null && cigarettesPerPack > 0
        ? (SurveyRecord.packCountEstimate(packsPerDay) * cigarettesPerPack)
              .round()
        : SurveyRecord.packsToLegacyCigarettes(packsPerDay);
    final estimatedCounts = _distributeCount(normalized, dailyCigarettes);
    final averageMinutesBetweenCigarettes = _computeAverageMinutesBetween(
      sleepMinutes: sleepMinutes,
      wakeMinutes: wakeMinutes,
      workStartMinutes: workStartMinutes,
      workEndMinutes: workEndMinutes,
      workplaceRule: workplaceRule,
      breakWindows: breakWindows,
      dailyCigarettes: dailyCigarettes,
    );

    final hourly = List<SmokingTimeSlot>.generate(
      24,
      (hour) => SmokingTimeSlot(
        hour: hour,
        weight: normalized[hour],
        estimatedCigarettes: estimatedCounts[hour],
      ),
    );

    final sortedByWeight = [...hourly]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final topHours = sortedByWeight
        .where((slot) => slot.weight > (1 / 24))
        .take(5)
        .map((slot) => slot.hour)
        .toList();

    var confidence = 0.35;
    if (sleepMinutes != null && wakeMinutes != null) {
      confidence += 0.1;
    }
    if (workStartMinutes != null && workEndMinutes != null) {
      confidence += 0.1;
    }
    if (hasWeeklyData) {
      confidence += 0.25;
    }

    return SmokingTimePrediction(
      hourly: hourly,
      topHours: topHours,
      confidence: confidence.clamp(0.0, 0.9),
      basis: hasWeeklyData ? 'structural+weekly' : 'structural',
      averageMinutesBetweenCigarettes: averageMinutesBetweenCigarettes,
    );
  }

  /// Spreads the user's smokable hours (a day minus sleep, further reduced
  /// by workplace hours where smoking isn't allowed) evenly across their
  /// estimated daily cigarette count. A rough pace estimate, not a
  /// schedule — real spacing is driven by the hourly distribution above.
  int? _computeAverageMinutesBetween({
    required int? sleepMinutes,
    required int? wakeMinutes,
    required int? workStartMinutes,
    required int? workEndMinutes,
    required String workplaceRule,
    required List<Map<String, dynamic>> breakWindows,
    required int dailyCigarettes,
  }) {
    if (sleepMinutes == null || wakeMinutes == null || dailyCigarettes <= 0) {
      return null;
    }

    final sleepDuration = _durationMinutes(sleepMinutes, wakeMinutes);
    var smokableMinutes = (24 * 60) - sleepDuration;

    if (workStartMinutes != null && workEndMinutes != null) {
      final workDuration = _durationMinutes(workStartMinutes, workEndMinutes);
      final noSmokingAtWork = workplaceRule.contains('hay');
      final onlyDuringBreaks = workplaceRule.contains('mola');

      if (noSmokingAtWork) {
        smokableMinutes -= workDuration;
      } else if (onlyDuringBreaks) {
        final breakMinutes = breakWindows.fold<int>(0, (sum, window) {
          final start = _parseMinutes(window['start']?.toString());
          final end = _parseMinutes(window['end']?.toString());
          if (start == null || end == null) {
            return sum;
          }
          return sum + _durationMinutes(start, end);
        });
        smokableMinutes -= (workDuration - breakMinutes).clamp(0, workDuration);
      }
    }

    // A floor rather than letting this go to zero/negative for someone
    // whose sleep+work windows happen to cover nearly the whole day —
    // still a useful (if conservative) pace estimate rather than nonsense.
    smokableMinutes = smokableMinutes.clamp(30, 24 * 60);
    return (smokableMinutes / dailyCigarettes).round();
  }

  int _durationMinutes(int startMinutes, int endMinutes) {
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    }
    return ((24 * 60) - startMinutes) + endMinutes;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  void _zeroSleepWindow(List<double> weights, int? sleepMin, int? wakeMin) {
    if (sleepMin == null || wakeMin == null) {
      return;
    }
    var hour = sleepMin ~/ 60;
    final endHour = wakeMin ~/ 60;
    // Sleep windows typically cross midnight (e.g. 23:00 -> 07:00); walk
    // forward hour-by-hour, wrapping at 24, until we reach the wake hour.
    while (hour != endHour) {
      weights[hour % 24] = 0;
      hour = (hour + 1) % 24;
    }
  }

  void _boostFirstCigarette(
    List<double> weights,
    int? wakeMin,
    String? firstCigaretteRange,
  ) {
    if (wakeMin == null) {
      return;
    }
    final offsetMinutes = switch (firstCigaretteRange) {
      '0-5' => 3,
      '5-10' => 7,
      '10-30' => 20,
      '30-60' => 45,
      '60+' => 90,
      _ => 20,
    };
    final hour = ((wakeMin + offsetMinutes) ~/ 60) % 24;
    weights[hour] += 1.2;
  }

  void _applyWorkplaceRule(
    List<double> weights, {
    required String workplaceRule,
    required int? workStartMinutes,
    required int? workEndMinutes,
    required List<Map<String, dynamic>> breakWindows,
  }) {
    if (workStartMinutes == null || workEndMinutes == null) {
      return;
    }
    final startHour = workStartMinutes ~/ 60;
    final endHour = workEndMinutes ~/ 60;
    final noSmokingAtWork = workplaceRule.contains('hay');
    final onlyDuringBreaks = workplaceRule.contains('mola');

    if (noSmokingAtWork || onlyDuringBreaks) {
      var hour = startHour;
      while (hour != endHour % 24) {
        weights[hour % 24] *= 0.25;
        hour = (hour + 1) % 24;
      }
      // A boosted moment right after work ends — a very common real-world
      // pattern for anyone who couldn't smoke freely during the day.
      weights[endHour % 24] += 0.9;
    }

    if (onlyDuringBreaks) {
      for (final window in breakWindows) {
        final start = _parseMinutes(window['start']?.toString());
        if (start == null) {
          continue;
        }
        weights[(start ~/ 60) % 24] += 1.0;
      }
    }
  }

  void _boostMealTimes(
    List<double> weights,
    Map<String, dynamic> mealSchedule,
    Map<String, dynamic> triggerExposureDays,
  ) {
    final mealTriggerDays = _toInt(triggerExposureDays['meal']);
    // Even without weekly data, meals are a common enough trigger to merit
    // a modest default boost; scale it up if the user has actually
    // confirmed meals are a trigger for them.
    final mealBoost = 0.5 + (mealTriggerDays / 7).clamp(0.0, 1.0) * 0.7;

    for (final key in ['lunchTime', 'dinnerTime']) {
      final minutes = _parseMinutes(mealSchedule[key]?.toString());
      if (minutes != null) {
        weights[(minutes ~/ 60) % 24] += mealBoost;
      }
    }
  }

  void _boostEveningTriggers(
    List<double> weights,
    Map<String, dynamic> triggerExposureDays,
  ) {
    final stressDays = _toInt(triggerExposureDays['stress']);
    final phoneDays = _toInt(triggerExposureDays['phone']);
    final socialDays = _toInt(triggerExposureDays['social']);
    final eveningSignal = (stressDays + phoneDays + socialDays) / 21;
    if (eveningSignal <= 0) {
      return;
    }
    for (final hour in [19, 20, 21, 22]) {
      weights[hour] += eveningSignal.clamp(0.0, 1.0) * 0.6;
    }
  }

  void _applyWeekendPattern(
    List<double> weights,
    String weekendPattern,
    bool isWeekend,
  ) {
    if (!isWeekend) {
      return;
    }
    if (weekendPattern.contains('fazla')) {
      for (var hour = 0; hour < 24; hour++) {
        weights[hour] *= 1.15;
      }
    } else if (weekendPattern.contains('az')) {
      for (var hour = 0; hour < 24; hour++) {
        weights[hour] *= 0.9;
      }
    }
  }

  List<int> _distributeCount(List<double> normalizedWeights, int total) {
    if (total <= 0) {
      return List<int>.filled(24, 0);
    }
    // Largest-remainder rounding so the 24 slots sum to exactly `total`
    // instead of drifting from independent rounding of each slot.
    final raw = normalizedWeights.map((w) => w * total).toList();
    final floors = raw.map((v) => v.floor()).toList();
    var remaining = total - floors.fold<int>(0, (sum, v) => sum + v);
    final remainderOrder = List<int>.generate(24, (i) => i)
      ..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
    final result = [...floors];
    for (final hour in remainderOrder) {
      if (remaining <= 0) {
        break;
      }
      result[hour] += 1;
      remaining -= 1;
    }
    return result;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _parseMinutes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return (hour.clamp(0, 23) * 60) + minute.clamp(0, 59);
  }
}
