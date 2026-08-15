import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/period_report.dart';

/// Tests for the two new PeriodReport fields added in the
/// İlerleme Raporları feature:
/// - estimatedAvertedCigarettes
/// - smokingTimePattern
void main() {
  PeriodReport buildReport({
    int? estimatedAverted,
    Map<String, double>? pattern,
  }) {
    return PeriodReport(
      periodStart: DateTime(2025, 1, 1),
      periodEnd: DateTime(2025, 1, 7),
      periodType: 'weekly',
      cigarettesLogged: 30,
      avgCigarettesPerDay: 4.3,
      riskScoreAtStart: 75,
      riskScoreAtEnd: 60,
      riskTrend: 'Improving',
      breathTrend: 'Improving',
      smokingTrend: 'Decreasing',
      taskSuccessCount: 12,
      taskFailureCount: 3,
      taskCompletionRate: 0.8,
      weeklySurveysCompleted: 1,
      breathTestsCompleted: 5,
      daysSinceQuitDate: 21,
      totalSteps: 45000,
      avgStepsPerDay: 6428.6,
      estimatedAvertedCigarettes: estimatedAverted,
      smokingTimePattern: pattern,
    );
  }

  group('PeriodReport basic construction', () {
    test('creates report with all required fields', () {
      final report = buildReport();
      expect(report.periodType, 'weekly');
      expect(report.cigarettesLogged, 30);
      expect(report.avgCigarettesPerDay, 4.3);
      expect(report.riskScoreAtStart, 75);
      expect(report.riskScoreAtEnd, 60);
      expect(report.riskTrend, 'Improving');
      expect(report.breathTrend, 'Improving');
      expect(report.smokingTrend, 'Decreasing');
      expect(report.taskSuccessCount, 12);
      expect(report.taskFailureCount, 3);
      expect(report.taskCompletionRate, 0.8);
      expect(report.weeklySurveysCompleted, 1);
      expect(report.breathTestsCompleted, 5);
      expect(report.daysSinceQuitDate, 21);
      expect(report.totalSteps, 45000);
      expect(report.avgStepsPerDay, 6428.6);
    });
  });

  group('estimatedAvertedCigarettes (new metric)', () {
    test('can hold a positive value when data exists', () {
      final report = buildReport(estimatedAverted: 25);
      expect(report.estimatedAvertedCigarettes, 25);
    });

    test('is null when insufficient baseline data', () {
      final report = buildReport(estimatedAverted: null);
      expect(report.estimatedAvertedCigarettes, isNull);
    });

    test('is null by default (optional field)', () {
      final report = PeriodReport(
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 7),
        periodType: 'weekly',
        cigarettesLogged: 30,
        avgCigarettesPerDay: 4.3,
        riskScoreAtStart: null,
        riskScoreAtEnd: null,
        riskTrend: 'Stable',
        breathTrend: 'Stable',
        smokingTrend: 'Stable',
        taskSuccessCount: 0,
        taskFailureCount: 0,
        taskCompletionRate: 0.0,
        weeklySurveysCompleted: 0,
        breathTestsCompleted: 0,
        daysSinceQuitDate: null,
        totalSteps: 0,
        avgStepsPerDay: 0.0,
      );
      expect(report.estimatedAvertedCigarettes, isNull);
    });

    test('can hold zero when no cigarettes were averted', () {
      final report = buildReport(estimatedAverted: 0);
      expect(report.estimatedAvertedCigarettes, 0);
    });
  });

  group('smokingTimePattern (new metric)', () {
    test('can hold a full day pattern with 5 parts', () {
      final pattern = {
        'morning': 0.3,
        'midday': 0.15,
        'afternoon': 0.25,
        'evening': 0.2,
        'night': 0.1,
      };
      final report = buildReport(pattern: pattern);

      expect(report.smokingTimePattern, isNotNull);
      expect(report.smokingTimePattern!.length, 5);
      expect(report.smokingTimePattern!['morning'], 0.3);
      expect(report.smokingTimePattern!['midday'], 0.15);
      expect(report.smokingTimePattern!['afternoon'], 0.25);
      expect(report.smokingTimePattern!['evening'], 0.2);
      expect(report.smokingTimePattern!['night'], 0.1);
    });

    test('sum of pattern values should be approximately 1.0', () {
      final pattern = {
        'morning': 0.3,
        'midday': 0.15,
        'afternoon': 0.25,
        'evening': 0.2,
        'night': 0.1,
      };
      final report = buildReport(pattern: pattern);
      final sum = report.smokingTimePattern!.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 0.001));
    });

    test('is null when too few events to determine a pattern', () {
      final report = buildReport(pattern: null);
      expect(report.smokingTimePattern, isNull);
    });

    test('is null by default (optional field)', () {
      final report = PeriodReport(
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 7),
        periodType: 'weekly',
        cigarettesLogged: 30,
        avgCigarettesPerDay: 4.3,
        riskScoreAtStart: null,
        riskScoreAtEnd: null,
        riskTrend: 'Stable',
        breathTrend: 'Stable',
        smokingTrend: 'Stable',
        taskSuccessCount: 0,
        taskFailureCount: 0,
        taskCompletionRate: 0.0,
        weeklySurveysCompleted: 0,
        breathTestsCompleted: 0,
        daysSinceQuitDate: null,
        totalSteps: 0,
        avgStepsPerDay: 0.0,
      );
      expect(report.smokingTimePattern, isNull);
    });

    test('can hold an empty pattern (edge case)', () {
      final report = buildReport(pattern: {});
      expect(report.smokingTimePattern, isNotNull);
      expect(report.smokingTimePattern!.isEmpty, isTrue);
    });

    test('pattern keys use expected part names', () {
      final validKeys = {
        'morning',
        'midday',
        'afternoon',
        'evening',
        'night',
      };
      final pattern = {
        'morning': 0.2,
        'evening': 0.8,
      };
      final report = buildReport(pattern: pattern);
      for (final key in report.smokingTimePattern!.keys) {
        expect(validKeys.contains(key), isTrue,
            reason: 'Unexpected pattern key: $key');
      }
    });
  });

  group('period types', () {
    test('weekly period type', () {
      final report = buildReport();
      expect(report.periodType, 'weekly');
    });

    test('monthly period type', () {
      final report = PeriodReport(
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 31),
        periodType: 'monthly',
        cigarettesLogged: 100,
        avgCigarettesPerDay: 3.2,
        riskScoreAtStart: 80,
        riskScoreAtEnd: 55,
        riskTrend: 'Improving',
        breathTrend: 'Improving',
        smokingTrend: 'Decreasing',
        taskSuccessCount: 40,
        taskFailureCount: 10,
        taskCompletionRate: 0.8,
        weeklySurveysCompleted: 4,
        breathTestsCompleted: 20,
        daysSinceQuitDate: 60,
        totalSteps: 150000,
        avgStepsPerDay: 4838.7,
      );
      expect(report.periodType, 'monthly');
      expect(report.cigarettesLogged, 100);
      expect(report.weeklySurveysCompleted, 4);
    });
  });
}
