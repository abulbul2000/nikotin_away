/// Canonical, language-independent IDs for MentorEngine's coaching commands.
///
/// MentorEngine used to return hardcoded Turkish sentences directly, which
/// broke for any other selected language. It now returns these IDs instead,
/// and AppTexts.localizeCanonicalTextForCode resolves them to the user's
/// language at display time -- the same pattern already used for
/// `ADAPTIVE_NO_SMOKE:{minutes}`.
///
/// Both mentor_engine.dart and app_texts.dart import this file so the two
/// sides can never drift out of sync on the literal strings.
abstract final class MentorCommandCodes {
  static const reductionTier75 = 'REDUCTION_TIER_75';
  static const reductionTier60 = 'REDUCTION_TIER_60';
  static const reductionTier40 = 'REDUCTION_TIER_40';
  static const reductionTierBase = 'REDUCTION_TIER_BASE';

  static const breathDeclining = 'BREATH_DECLINING';
  static const breathImproving = 'BREATH_IMPROVING';
  static const breathStable = 'BREATH_STABLE';

  static const trackReduceToday = 'TRACK_REDUCE_TODAY';
  static const trackCompleteThree = 'TRACK_COMPLETE_THREE';

  static const triggerStress = 'TRIGGER_STRESS';
  static const triggerCoffee = 'TRIGGER_COFFEE';
  static const triggerAlcohol = 'TRIGGER_ALCOHOL';
  static const triggerSocial = 'TRIGGER_SOCIAL';
  static const crisisProtocol = 'CRISIS_PROTOCOL';
  static const supportSingleGoal = 'SUPPORT_SINGLE_GOAL';

  static const hintHighRisk = 'HINT_HIGH_RISK';
  static const hintMedRisk = 'HINT_MED_RISK';
  static const hintLowRisk = 'HINT_LOW_RISK';

  /// `ADAPTIVE_NO_SMOKE:{minutes}` already existed before this refactor and
  /// is intentionally left as-is -- AppTexts already resolves it.
  static const adaptiveNoSmokePrefix = 'ADAPTIVE_NO_SMOKE';
  static const adaptiveNoSmokeWindowPrefix = 'ADAPTIVE_NO_SMOKE_WINDOW';
  static const prepWindowPrefix = 'PREP_WINDOW';
  static const triggerDelayPrefix = 'TRIGGER_DELAY';
  static const focusRiskHourPrefix = 'FOCUS_RISK_HOUR';
  static const weeklyTargetPrefix = 'WEEKLY_TARGET';
  static const hintWindowPrefix = 'HINT_WINDOW';
  static const hintTriggerPrefix = 'HINT_TRIGGER';
  static const riskDaypartPrefix = 'RISKDAYPART';

  static const toneSoftSuffix = ':soft';
  static const toneActiveSuffix = ':active';

  static String riskDaypartId({
    required String band,
    required String dayPart,
    required int index,
  }) {
    return '${riskDaypartPrefix}_${band.toUpperCase()}_${dayPart.toUpperCase()}_$index';
  }
}
