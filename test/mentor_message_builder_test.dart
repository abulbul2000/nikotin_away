import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/mentor_command_codes.dart';
import 'package:no_smoke/engines/mentor_message_builder.dart';

void main() {
  final builder = MentorMessageBuilder();

  test('uses coach tone when recent success rate is high', () {
    final message = builder.buildDailyMessage(
      riskScore: 30,
      recentSuccessRate: 0.85,
      riskyHours: const ['20:00-22:00'],
      now: DateTime(2026, 1, 1, 10, 0),
    );
    expect(message.tone, 'coach');
    expect(message.type, 'daily');
    expect(message.text, MentorMessageCodes.dailyCoachNoHour);
  });

  test('never names a risky-hour window, even one still ahead today', () {
    // The mentor used to name the nearest upcoming risky-hour window
    // ("18:00-20:00 aralığında yanındayım"), but that message is cached
    // for the rest of the day once generated — read hours later, after
    // the window has passed, it reads as the mentor not knowing what
    // time it is. Simplest fix: never name a window at all.
    final message = builder.buildDailyMessage(
      riskScore: 30,
      recentSuccessRate: 0.85,
      riskyHours: const ['14:00-16:00', '20:00-22:00'],
      now: DateTime(2026, 1, 1, 10, 0),
    );
    expect(message.text, MentorMessageCodes.dailyCoachNoHour);
  });

  test('uses supportive tone and an extra quick reply when struggling', () {
    final message = builder.buildDailyMessage(
      riskScore: 70,
      recentSuccessRate: 0.2,
      riskyHours: const [],
    );
    expect(message.tone, 'supportive');
    expect(message.text, MentorMessageCodes.dailySupportive);
    expect(message.quickReplies, contains(MentorMessageCodes.quickReplyNoTalk));
  });

  test('uses neutral tone for middling success rates', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
    );
    expect(message.tone, 'neutral');
    expect(message.text, MentorMessageCodes.dailyNeutralNoHour);
  });

  test('appends the historical note code when provided', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
      historicalNote: '${MentorMessageCodes.histWorseningPrefix}:evening',
    );
    expect(
      message.text,
      contains('${MentorMessageCodes.histWorseningPrefix}:evening'),
    );
  });

  test('appends the breath-improving code for an improving breath trend', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
      breathTrend: 'improving',
    );
    expect(message.text, contains(MentorMessageCodes.breathImprovingNote));
  });

  test('says nothing about breath trend when stable or worsening', () {
    final stable = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
    );
    final worsening = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
      breathTrend: 'worsening',
    );
    expect(
      stable.text,
      isNot(contains(MentorMessageCodes.breathImprovingNote)),
    );
    expect(
      worsening.text,
      isNot(contains(MentorMessageCodes.breathImprovingNote)),
    );
  });

  test('buildHistoricalNote returns null with too little history', () {
    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 1},
      thisWeekDayPartCounts: const {'evening': 0},
    );
    expect(note, isNull);
  });

  test(
    'buildHistoricalNote flags a recurring struggle in the same day part',
    () {
      final note = builder.buildHistoricalNote(
        lastWeekDayPartCounts: const {'evening': 5, 'morning': 1},
        thisWeekDayPartCounts: const {'evening': 5, 'morning': 0},
      );
      expect(note, '${MentorMessageCodes.histWorseningPrefix}:evening');
    },
  );

  test('buildHistoricalNote recognizes improvement in the flagged day part '
      'once that part has had a chance to occur this week', () {
    // Wednesday — 'evening' has already happened at least once this week
    // (Monday and Tuesday evenings), so a zero count here is real signal.
    final startOfThisWeek = DateTime(2026, 7, 20); // Monday
    final now = DateTime(2026, 7, 22, 9, 0); // Wednesday morning

    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 5},
      thisWeekDayPartCounts: const {'evening': 0},
      startOfThisWeek: startOfThisWeek,
      now: now,
    );
    expect(note, '${MentorMessageCodes.histImprovedPrefix}:evening');
  });

  test('buildHistoricalNote without week-boundary args keeps trusting a zero '
      'count as-is (existing behavior for callers that pass neither)', () {
    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 5},
      thisWeekDayPartCounts: const {'evening': 0},
    );
    expect(note, '${MentorMessageCodes.histImprovedPrefix}:evening');
  });

  group(
    'buildHistoricalNote day-part-not-occurred-yet (regression coverage)',
    () {
      // Regression coverage: comparing a complete last week against a
      // partial this week used to report "you improved!" for a day part
      // that simply hasn't happened yet this week — e.g. a Monday 9am
      // mentor message congratulating the user on quieter evenings, when
      // no evening has occurred since the week started at all.
      test('Monday morning does not claim improvement in "evening", which '
          "hasn't happened yet this week", () {
        final startOfThisWeek = DateTime(2026, 7, 20); // Monday
        final now = DateTime(2026, 7, 20, 9, 0); // Monday 9am, same day

        final note = builder.buildHistoricalNote(
          lastWeekDayPartCounts: const {'evening': 5},
          thisWeekDayPartCounts: const {'evening': 0},
          startOfThisWeek: startOfThisWeek,
          now: now,
        );
        expect(note, isNull);
      });

      test('Monday evening does claim improvement once evening has actually '
          'occurred today', () {
        final startOfThisWeek = DateTime(2026, 7, 20); // Monday
        final now = DateTime(2026, 7, 20, 20, 0); // Monday 8pm — evening

        final note = builder.buildHistoricalNote(
          lastWeekDayPartCounts: const {'evening': 5},
          thisWeekDayPartCounts: const {'evening': 0},
          startOfThisWeek: startOfThisWeek,
          now: now,
        );
        expect(note, '${MentorMessageCodes.histImprovedPrefix}:evening');
      });

      test('a non-zero this-week count is never suppressed by the '
          'not-occurred-yet check, even early in the week', () {
        final startOfThisWeek = DateTime(2026, 7, 20); // Monday
        final now = DateTime(2026, 7, 20, 9, 0); // Monday 9am

        final note = builder.buildHistoricalNote(
          lastWeekDayPartCounts: const {'evening': 5},
          thisWeekDayPartCounts: const {'evening': 2},
          startOfThisWeek: startOfThisWeek,
          now: now,
        );
        expect(note, isNotNull);
      });
    },
  );

  test('dayPartForHour buckets hours correctly', () {
    expect(MentorMessageBuilder.dayPartForHour(6), 'morning');
    expect(MentorMessageBuilder.dayPartForHour(13), 'afternoon');
    expect(MentorMessageBuilder.dayPartForHour(19), 'evening');
    expect(MentorMessageBuilder.dayPartForHour(23), 'night');
    expect(MentorMessageBuilder.dayPartForHour(2), 'night');
  });

  test('buildWeeklyMessage produces a weekly-typed message', () {
    final message = builder.buildWeeklyMessage(
      weeklyRiskScore: 40,
      weeklyRiskLevel: 'medium',
      recentSuccessRate: 0.6,
      completedTasksThisWeek: 12,
    );
    expect(message.type, 'weekly');
    expect(message.text, '${MentorMessageCodes.weeklyNeutralPrefix}:medium');
    expect(
      message.quickReplies,
      contains(MentorMessageCodes.quickReplyFillWeeklySurvey),
    );
  });

  test(
    'buildReframedViolationMessage reframes suspicious behavior with a task title',
    () {
      final message = builder.buildReframedViolationMessage(
        violationType: 'suspicious_behavior',
        taskTitle: '10 dakika sigarasiz kal',
      );
      expect(message, isNotNull);
      expect(
        message!.text,
        '${MentorMessageCodes.reframeSuspiciousWithTitle}:10 dakika sigarasiz kal',
      );
      expect(message.tone, 'supportive');
    },
  );

  test(
    'buildReframedViolationMessage returns null for an unknown violation type',
    () {
      final message = builder.buildReframedViolationMessage(
        violationType: 'unknown_type',
      );
      expect(message, isNull);
    },
  );
}
