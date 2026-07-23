import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/mentor_message_builder.dart';

void main() {
  final builder = MentorMessageBuilder();

  test('uses coach tone when recent success rate is high', () {
    final message = builder.buildDailyMessage(
      riskScore: 30,
      recentSuccessRate: 0.85,
      riskyHours: const ['20:00-22:00'],
    );
    expect(message.tone, 'coach');
    expect(message.type, 'daily');
  });

  test('uses supportive tone and an extra quick reply when struggling', () {
    final message = builder.buildDailyMessage(
      riskScore: 70,
      recentSuccessRate: 0.2,
      riskyHours: const [],
    );
    expect(message.tone, 'supportive');
    expect(message.quickReplies, contains('Konuşmak istemiyorum'));
  });

  test('uses neutral tone for middling success rates', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
    );
    expect(message.tone, 'neutral');
  });

  test('appends the historical note when provided', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
      historicalNote: 'Geçen hafta akşamları zorlanmıştın.',
    );
    expect(message.text, contains('Geçen hafta akşamları zorlanmıştın.'));
  });

  test('mentions an improving breath trend in the daily message', () {
    final message = builder.buildDailyMessage(
      riskScore: 50,
      recentSuccessRate: 0.55,
      riskyHours: const [],
      breathTrend: 'improving',
    );
    expect(message.text, contains('nefes testlerin de iyiye gidiyor'));
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
    expect(stable.text, isNot(contains('nefes testlerin')));
    expect(worsening.text, isNot(contains('nefes testlerin')));
  });

  test('buildHistoricalNote returns null with too little history', () {
    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 1},
      thisWeekDayPartCounts: const {'evening': 0},
    );
    expect(note, isNull);
  });

  test('buildHistoricalNote flags a recurring struggle in the same day part', () {
    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 5, 'morning': 1},
      thisWeekDayPartCounts: const {'evening': 4, 'morning': 0},
    );
    expect(note, isNotNull);
    expect(note, contains('akşamları'));
  });

  test('buildHistoricalNote recognizes improvement in the flagged day part', () {
    final note = builder.buildHistoricalNote(
      lastWeekDayPartCounts: const {'evening': 5},
      thisWeekDayPartCounts: const {'evening': 0},
    );
    expect(note, contains('harika'));
  });

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
    expect(message.quickReplies, contains('Haftalık anketi doldur'));
  });
}
