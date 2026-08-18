/// Computes a single respiratory-burden score from a weekly survey's
/// `respiratory` payload (mMRC grade, CAT-like symptom sliders, warning-sign
/// day counts) and classifies it into a state a person can act on.
///
/// Pure and DB-free like the other engines. Previously this exact formula —
/// the 0.35/0.45/0.20 weighting, the same clamps, the same 65/35 state
/// thresholds — was written out independently in both
/// `personal_progress_page.dart` and `weekly_survey_page.dart`. Duplication
/// between two pages is how a threshold tweak in one silently stops
/// matching the other; worse, `weekly_survey_page.dart` used its copy to
/// decide a real thing (how many breath tests the next day's plan asks
/// for), which is a business rule and has no business living in a page.
class RespiratoryBurdenEngine {
  const RespiratoryBurdenEngine._();

  /// `payload` is a weekly survey's decoded `respiratory` JSON blob — the
  /// same shape `WeeklySurveyPage` writes and `PersonalProgressPage` reads
  /// back. Returns 0 for any field that's missing so an older record
  /// without a given warning-sign question still scores instead of
  /// throwing.
  static double calculateBurden(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final mmrc = _toInt(respiratory['mmrcGrade']).clamp(1, 5);
    final catTotal =
        _toInt(catLike['cough']) +
        _toInt(catLike['phlegm']) +
        _toInt(catLike['chestTightness']) +
        _toInt(catLike['breathlessnessStairs']) +
        _toInt(catLike['activityLimitation']) +
        _toInt(catLike['confidenceLeavingHome']) +
        _toInt(catLike['sleepQualityResp']) +
        _toInt(catLike['energyLevelResp']);
    final warningTotal = _warningTotal(warningSigns);

    final mmrcComponent = ((mmrc - 1) / 4) * 100;
    final catComponent = (catTotal / 40) * 100;
    final warningComponent = ((warningTotal / 28) * 100).clamp(0, 100);

    return ((0.35 * mmrcComponent) +
            (0.45 * catComponent) +
            (0.20 * warningComponent))
        .clamp(0, 100)
        .toDouble();
  }

  /// 'clinical_review_recommended', 'monitor_closer', or 'stable'.
  ///
  /// `severeCombo` can push straight to the top state even when the
  /// weighted [calculateBurden] score alone would not — two consecutive
  /// warning signs are a stronger signal than either contributing to the
  /// weighted average diluted by everything else in the survey.
  static String resolveState(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final mmrc = _toInt(respiratory['mmrcGrade']).clamp(1, 5);
    final warningNight = _toInt(
      warningSigns['increasedNightBreathlessnessDays'],
    ).clamp(0, 7);
    final warningSputumColor = _toInt(
      warningSigns['sputumColorChangeDays'],
    ).clamp(0, 7);
    final burden = calculateBurden(payload);

    final severeCombo =
        (mmrc >= 4 && warningNight >= 4) ||
        (warningNight >= 4 && warningSputumColor >= 3);
    if (burden >= 65 || severeCombo) {
      return 'clinical_review_recommended';
    }
    if (burden >= 35 || warningNight >= 3 || warningSputumColor >= 2) {
      return 'monitor_closer';
    }
    return 'stable';
  }

  /// `burden`/`state` plus the raw component figures a progress view wants
  /// to show alongside them (mMRC grade, CAT-like total out of 40,
  /// warning-sign days out of 28) — bundled so a caller displaying all of
  /// it does not have to re-extract catTotal/warningTotal a third time
  /// from the same payload the engine already walked.
  static Map<String, dynamic> snapshot(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final mmrc = _toInt(respiratory['mmrcGrade']).clamp(1, 5);
    final catTotal =
        _toInt(catLike['cough']) +
        _toInt(catLike['phlegm']) +
        _toInt(catLike['chestTightness']) +
        _toInt(catLike['breathlessnessStairs']) +
        _toInt(catLike['activityLimitation']) +
        _toInt(catLike['confidenceLeavingHome']) +
        _toInt(catLike['sleepQualityResp']) +
        _toInt(catLike['energyLevelResp']);
    final warningTotal = _warningTotal(warningSigns);

    return {
      'burden': calculateBurden(payload),
      'state': resolveState(payload),
      'mmrc': mmrc,
      'catTotal': catTotal,
      'warningTotal': warningTotal,
    };
  }

  static int _warningTotal(Map<String, dynamic> warningSigns) {
    final night = _toInt(
      warningSigns['increasedNightBreathlessnessDays'],
    ).clamp(0, 7);
    final sputumInc = _toInt(warningSigns['sputumIncreaseDays']).clamp(0, 7);
    final sputumColor = _toInt(
      warningSigns['sputumColorChangeDays'],
    ).clamp(0, 7);
    final wheeze = _toInt(warningSigns['wheezeDays']).clamp(0, 7);
    return night + sputumInc + sputumColor + wheeze;
  }

  /// A high burden earns one extra daily breath test on top of
  /// [baseDailyTarget] — the plan asking for a closer look is exactly the
  /// "real thing" this score is meant to drive, not just a number shown on
  /// a progress screen.
  static int resolveEffectiveDailyBreathTarget(
    Map<String, dynamic> payload,
    int baseDailyTarget,
  ) {
    final burden = calculateBurden(payload);
    var target = baseDailyTarget;
    if (burden >= 65) {
      target = (target + 1).clamp(1, 4);
    }
    return target;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}
