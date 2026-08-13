import '../core/mentor_command_codes.dart';
import '../models/mentor_message.dart';

/// Turns the app's existing coaching signals (risk score, risky hours,
/// recent task success rate, week-over-week smoking-event patterns) into a
/// single personalized [MentorMessage] — the mentor's "voice" — instead of
/// the stateless one-off command strings [MentorEngine] otherwise produces.
///
/// Tone adapts to how the user has been doing recently rather than being
/// fixed: a high recent success rate gets a coach-like nudge, a low one
/// gets a gentler, more supportive message, and anything in between stays
/// neutral. This is a deliberately simple, rule-based, fully-offline
/// implementation — see the "AI-backed replies" tier discussion for a
/// future richer alternative gated behind the top payment tier.
///
/// `text`/`quickReplies`/`userReply` are all canonical IDs (see
/// [MentorMessageCodes]), not literal strings — the result gets persisted
/// to SQLite, so a hardcoded language choice here would be baked into the
/// user's history forever. AppTexts.localizeMentorMessage resolves them to
/// the user's language at display time.
class MentorMessageBuilder {
  static const List<String> _dayParts = [
    'morning',
    'afternoon',
    'evening',
    'night',
  ];

  String _tone(double recentSuccessRate) {
    if (recentSuccessRate >= 0.7) {
      return 'coach';
    }
    if (recentSuccessRate <= 0.4) {
      return 'supportive';
    }
    return 'neutral';
  }

  MentorMessage buildDailyMessage({
    required int riskScore,
    required double recentSuccessRate,
    required List<String> riskyHours,
    String? historicalNote,
    String breathTrend = 'stable',
    DateTime? now,
  }) {
    final tone = _tone(recentSuccessRate);
    final timestamp = now ?? DateTime.now();

    final segments = <String>[];
    switch (tone) {
      case 'coach':
        segments.add(MentorMessageCodes.dailyCoachNoHour);
        break;
      case 'supportive':
        segments.add(MentorMessageCodes.dailySupportive);
        break;
      default:
        segments.add(MentorMessageCodes.dailyNeutralNoHour);
    }

    if (breathTrend == 'improving') {
      segments.add(MentorMessageCodes.breathImprovingNote);
    }

    if (historicalNote != null && historicalNote.isNotEmpty) {
      segments.add(historicalNote);
    }

    final quickReplies = tone == 'supportive'
        ? const [
            MentorMessageCodes.quickReplyOk,
            MentorMessageCodes.quickReplyStruggling,
            MentorMessageCodes.quickReplyNoTalk,
          ]
        : const [
            MentorMessageCodes.quickReplyOk,
            MentorMessageCodes.quickReplyStruggling,
          ];

    return MentorMessage(
      id: 'mentor_daily_${timestamp.millisecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'daily',
      text: segments.join(MentorMessageCodes.segmentSeparator),
      tone: tone,
      quickReplies: quickReplies,
      read: false,
    );
  }

  MentorMessage buildWeeklyMessage({
    required int weeklyRiskScore,
    required String weeklyRiskLevel,
    required double recentSuccessRate,
    required int completedTasksThisWeek,
    String? historicalNote,
    DateTime? now,
  }) {
    final tone = _tone(recentSuccessRate);
    final timestamp = now ?? DateTime.now();

    final segments = <String>[];
    switch (tone) {
      case 'coach':
        segments.add(
          '${MentorMessageCodes.weeklyCoachPrefix}:$completedTasksThisWeek',
        );
        break;
      case 'supportive':
        segments.add(MentorMessageCodes.weeklySupportive);
        break;
      default:
        segments.add(
          '${MentorMessageCodes.weeklyNeutralPrefix}:$weeklyRiskLevel',
        );
    }

    if (historicalNote != null && historicalNote.isNotEmpty) {
      segments.add(historicalNote);
    }

    return MentorMessage(
      id: 'mentor_weekly_${timestamp.millisecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'weekly',
      text: segments.join(MentorMessageCodes.segmentSeparator),
      tone: tone,
      quickReplies: const [
        MentorMessageCodes.quickReplyFillWeeklySurvey,
        MentorMessageCodes.quickReplyLater,
      ],
      read: false,
    );
  }

  /// Builds a "geçen hafta X zamanları zorlanmıştın, bu hafta nasıl?" style
  /// callback by comparing which part of the day smoking events clustered
  /// in last week versus this week. Returns null when there isn't enough
  /// data yet to say anything meaningful — a quiet mentor beats a wrong one.
  ///
  /// Returns a canonical `MENTOR_HIST_*:dayPart` code, not literal text.
  String? buildHistoricalNote({
    required Map<String, int> lastWeekDayPartCounts,
    required Map<String, int> thisWeekDayPartCounts,
  }) {
    final lastWeekTotal = lastWeekDayPartCounts.values.fold(0, (a, b) => a + b);
    if (lastWeekTotal < 3) {
      // Too little history to draw any pattern from.
      return null;
    }

    String? dominantPart;
    var dominantCount = 0;
    for (final part in _dayParts) {
      final count = lastWeekDayPartCounts[part] ?? 0;
      if (count > dominantCount) {
        dominantCount = count;
        dominantPart = part;
      }
    }
    if (dominantPart == null || dominantCount < 2) {
      return null;
    }

    final thisWeekCount = thisWeekDayPartCounts[dominantPart] ?? 0;

    if (thisWeekCount == 0) {
      return '${MentorMessageCodes.histImprovedPrefix}:$dominantPart';
    }
    if (thisWeekCount >= dominantCount) {
      return '${MentorMessageCodes.histWorseningPrefix}:$dominantPart';
    }
    return '${MentorMessageCodes.histSimilarPrefix}:$dominantPart';
  }

  /// Reframes a protocol-violation event (logged by
  /// `ProtocolViolationService`) as a supportive mentor message instead of
  /// a bare "violation recorded" alert — the discipline-protocol machinery
  /// keeps running underneath, but the user-facing voice is the mentor's.
  MentorMessage? buildReframedViolationMessage({
    required String violationType,
    String? taskTitle,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    String text;
    String tone;
    List<String> quickReplies = const [];

    switch (violationType) {
      case 'suspicious_behavior':
        text = taskTitle != null
            ? '${MentorMessageCodes.reframeSuspiciousWithTitle}:$taskTitle'
            : MentorMessageCodes.reframeSuspiciousNoTitle;
        tone = 'supportive';
        quickReplies = const [
          MentorMessageCodes.quickReplyOk,
          MentorMessageCodes.quickReplyLetsTalk,
        ];
        break;
      case 'willpower_weakness':
      case 'followup_failed':
        text = MentorMessageCodes.reframeWillpower;
        tone = 'supportive';
        quickReplies = const [MentorMessageCodes.quickReplyThanks];
        break;
      case 'deferred_start':
        text = MentorMessageCodes.reframeDeferredStart;
        tone = 'neutral';
        break;
      case 'followup_deferred':
        text = MentorMessageCodes.reframeFollowupDeferred;
        tone = 'neutral';
        break;
      case 'duration_barrier_failure':
        text = MentorMessageCodes.reframeDurationBarrier;
        tone = 'supportive';
        quickReplies = const [MentorMessageCodes.quickReplyOkAck];
        break;
      default:
        return null;
    }

    return MentorMessage(
      id: 'mentor_reframe_${timestamp.microsecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'reframed_violation',
      text: text,
      tone: tone,
      quickReplies: quickReplies,
      read: false,
    );
  }

  /// Buckets an hour-of-day (0-23) into a day part, matching the labels
  /// used by [buildHistoricalNote].
  static String dayPartForHour(int hour) {
    if (hour >= 5 && hour < 11) {
      return 'morning';
    }
    if (hour >= 11 && hour < 17) {
      return 'afternoon';
    }
    if (hour >= 17 && hour < 22) {
      return 'evening';
    }
    return 'night';
  }
}
