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

  static final RegExp _adaptiveNoSmokePattern = RegExp(
    r'^ADAPTIVE_NO_SMOKE:(\d+)$',
    caseSensitive: false,
  );

  /// Whether [command] is a duration-barrier task in its canonical form —
  /// the single place this check lives, so a barrier task is recognised the
  /// same way everywhere it's asked about (task-state lookups, outcome
  /// summaries, mentor command generation) rather than each call site
  /// re-implementing its own pattern and silently drifting from the others.
  static bool isDurationBarrierCommand(String command) {
    return _adaptiveNoSmokePattern.hasMatch(command.trim());
  }

  /// The planned minute count for a canonical duration-barrier command, or
  /// null if [command] isn't one (see [isDurationBarrierCommand]).
  static int? durationBarrierMinutes(String command) {
    final match = _adaptiveNoSmokePattern.firstMatch(command.trim());
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }
}

/// Canonical, language-independent IDs for [MentorMessageBuilder]'s messages.
///
/// MentorMessageBuilder used to return hardcoded Turkish sentences directly
/// as `MentorMessage.text`/`quickReplies`, and those get persisted to
/// SQLite -- so unlike a widget string, a hardcoded language choice there
/// is baked into the user's history forever, not just mis-rendered until
/// the next locale change. It now composes these IDs instead;
/// AppTexts.localizeMentorMessage resolves them to the user's language at
/// *display* time, same pattern as [MentorCommandCodes] one layer up.
///
/// Composite messages (tone body + optional breath note + optional
/// historical note) are joined with [segmentSeparator] into one `text`
/// string; AppTexts splits on it and resolves each segment independently.
abstract final class MentorMessageCodes {
  static const segmentSeparator = '|MSEG|';

  static const dailyCoachWithHour = 'MENTOR_DAILY_COACH_HOUR';
  static const dailyCoachNoHour = 'MENTOR_DAILY_COACH_NOHOUR';
  static const dailySupportive = 'MENTOR_DAILY_SUPPORTIVE';
  static const dailyNeutralWithHour = 'MENTOR_DAILY_NEUTRAL_HOUR';
  static const dailyNeutralNoHour = 'MENTOR_DAILY_NEUTRAL_NOHOUR';
  static const breathImprovingNote = 'MENTOR_BREATH_IMPROVING_NOTE';

  static const weeklyCoachPrefix = 'MENTOR_WEEKLY_COACH';
  static const weeklySupportive = 'MENTOR_WEEKLY_SUPPORTIVE';
  static const weeklyNeutralPrefix = 'MENTOR_WEEKLY_NEUTRAL';

  static const histWorseningPrefix = 'MENTOR_HIST_WORSENING';
  static const histImprovedPrefix = 'MENTOR_HIST_IMPROVED';
  static const histSimilarPrefix = 'MENTOR_HIST_SIMILAR';

  static const reframeSuspiciousWithTitle = 'MENTOR_REFRAME_SUSPICIOUS_TITLE';
  static const reframeSuspiciousNoTitle = 'MENTOR_REFRAME_SUSPICIOUS_NOTITLE';
  static const reframeWillpower = 'MENTOR_REFRAME_WILLPOWER';
  static const reframeDeferredStart = 'MENTOR_REFRAME_DEFERRED_START';
  static const reframeFollowupDeferred = 'MENTOR_REFRAME_FOLLOWUP_DEFERRED';
  static const reframeDurationBarrier = 'MENTOR_REFRAME_DURATION_BARRIER';

  static const quickReplyOk = 'QUICK_REPLY_OK';
  static const quickReplyStruggling = 'QUICK_REPLY_STRUGGLING';
  static const quickReplyNoTalk = 'QUICK_REPLY_NO_TALK';
  static const quickReplyFillWeeklySurvey = 'QUICK_REPLY_FILL_WEEKLY_SURVEY';
  static const quickReplyLater = 'QUICK_REPLY_LATER';
  static const quickReplyThanks = 'QUICK_REPLY_THANKS';
  static const quickReplyLetsTalk = 'QUICK_REPLY_LETS_TALK';
  static const quickReplyOkAck = 'QUICK_REPLY_OK_ACK';

  // The "Zorlanıyorum" follow-up question, its 3 answer options, and the
  // confirmation shown once the user has picked one.
  static const followUpStrugglingQuestion = 'MENTOR_FOLLOWUP_STRUGGLING_Q';
  static const quickReplyReduceTasks = 'QUICK_REPLY_REDUCE_TASKS';
  static const quickReplyEaseBarrier = 'QUICK_REPLY_EASE_BARRIER';
  static const quickReplyJustTalking = 'QUICK_REPLY_JUST_TALKING';
  static const followUpAckReduceTasks = 'MENTOR_FOLLOWUP_ACK_REDUCE_TASKS';
  static const followUpAckEaseBarrier = 'MENTOR_FOLLOWUP_ACK_EASE_BARRIER';
  static const followUpAckJustTalking = 'MENTOR_FOLLOWUP_ACK_JUST_TALKING';
}

/// Canonical, language-independent IDs for [BehaviorEngine.buildRiskExplanation]'s
/// lines. These get persisted (`behavior_snapshot.riskExplanation`) and shown
/// under the risk-score card's translated title, so — same reasoning as
/// [MentorMessageCodes] — a hardcoded Turkish sentence here isn't just
/// mis-rendered until the next locale change, it's baked into the user's
/// history in the wrong language forever. AppTexts.localizeCanonicalTextForCode
/// resolves each of these to the user's language at display time.
abstract final class RiskExplanationCodes {
  static const baseScorePrefix = 'RISK_BASE';
  static const behaviorDeltaPrefix = 'RISK_BEHAVIOR_DELTA';
  static const personalizedDeltaPrefix = 'RISK_PERSONALIZED_DELTA';
  static const profileDeltaPrefix = 'RISK_PROFILE_DELTA';
  static const taskDeltaPrefix = 'RISK_TASK_DELTA';
  static const finalScorePrefix = 'RISK_FINAL';
}

/// `DELAY_FIRST_CIGARETTE:{minutes}` — the very first task a brand-new
/// profile gets ([BehaviorEngine.generateAdaptiveTasks]'s `isFirstProfile`
/// branch) used to be a hardcoded Turkish sentence, so a user who selected
/// any other language got their first task in Turkish. Resolved the same
/// way as `ADAPTIVE_NO_SMOKE:{minutes}`.
abstract final class DelayFirstCigaretteCode {
  static const prefix = 'DELAY_FIRST_CIGARETTE';
}
