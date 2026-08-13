import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_trend_engine.dart';
import 'package:no_smoke/models/breath_progress_record.dart';
import 'package:no_smoke/models/breath_progress_summary.dart';

BreathProgressRecord _record({
  required DateTime completedAt,
  required double breathScore,
  double blowDurationSeconds = 8,
  double blowStability = 0.7,
  double blowIntensity = 0.7,
  bool isNoisyEnvironment = false,
  int schemaVersion = BreathProgressRecord.currentSchemaVersion,
}) {
  return BreathProgressRecord(
    id: 'r_${completedAt.millisecondsSinceEpoch}',
    completedAt: completedAt,
    breathScore: breathScore,
    blowDurationSeconds: blowDurationSeconds,
    blowStability: blowStability,
    blowIntensity: blowIntensity,
    isNoisyEnvironment: isNoisyEnvironment,
    schemaVersion: schemaVersion,
  );
}

void main() {
  group('BreathTrendEngine.computeScore', () {
    final engine = BreathTrendEngine();

    test('weights duration 50%, stability 30%, intensity 20%', () {
      final score = engine.computeScore(
        blowDurationSeconds: 10, // duration signal = 1.0
        blowStability: 1.0,
        blowIntensity: 1.0,
      );
      expect(score, closeTo(100, 0.001));
    });

    test('zero inputs produce zero score', () {
      final score = engine.computeScore(
        blowDurationSeconds: 0,
        blowStability: 0,
        blowIntensity: 0,
      );
      expect(score, 0);
    });

    test('duration signal clamps at the 10s ceiling', () {
      final at10 = engine.computeScore(
        blowDurationSeconds: 10,
        blowStability: 0,
        blowIntensity: 0,
      );
      final at30 = engine.computeScore(
        blowDurationSeconds: 30,
        blowStability: 0,
        blowIntensity: 0,
      );
      expect(at10, closeTo(50, 0.001));
      expect(at30, closeTo(50, 0.001));
    });

    test(
      'different plausible blow durations produce different scores '
      '(regression: with real exhale-only durations, the old 15s ceiling '
      'combined with the old inflated-duration bug meant every attempt '
      'saturated the duration signal to 1.0)',
      () {
        final short = engine.computeScore(
          blowDurationSeconds: 3,
          blowStability: 0.7,
          blowIntensity: 0.7,
        );
        final medium = engine.computeScore(
          blowDurationSeconds: 6,
          blowStability: 0.7,
          blowIntensity: 0.7,
        );
        final long = engine.computeScore(
          blowDurationSeconds: 9,
          blowStability: 0.7,
          blowIntensity: 0.7,
        );
        expect(short, lessThan(medium));
        expect(medium, lessThan(long));
      },
    );
  });

  group('BreathTrendEngine.medianOfAttemptScores', () {
    final engine = BreathTrendEngine();

    test('odd count returns the middle value', () {
      expect(engine.medianOfAttemptScores([30, 80, 50]), 50);
    });

    test('even count averages the two middle values', () {
      expect(engine.medianOfAttemptScores([10, 20, 30, 40]), 25);
    });

    test('empty list returns 0', () {
      expect(engine.medianOfAttemptScores(const []), 0);
    });

    test('best attempt does not dominate — a lucky high score is pulled '
        'toward the middle', () {
      // Median (50) is far below the max (95) — this is the whole point of
      // using median over best-of: a single lucky attempt shouldn't set the
      // recorded score.
      final median = engine.medianOfAttemptScores([40, 50, 95]);
      expect(median, 50);
      expect(median, lessThan(95));
    });
  });

  group('BreathTrendEngine.summarize — empty/insufficient data', () {
    final engine = BreathTrendEngine();

    test('empty record list returns BreathProgressSummary.empty()', () {
      final summary = engine.summarize(const [], languageCode: 'tr');
      expect(summary.hasData, isFalse);
      expect(summary.totalTestCount, 0);
      expect(summary.insightMessage, '');
    });

    test('fewer than minimumTestCountForTrend records: no trend shown', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        BreathTrendEngine.minimumTestCountForTrend - 1,
        (i) =>
            _record(completedAt: base.add(Duration(days: i)), breathScore: 50),
      );

      final summary = engine.summarize(records, languageCode: 'tr');
      expect(summary.hasEnoughDataForTrend, isFalse);
      expect(summary.scoreChangeFirstWeekVsLastWeekPercent, isNull);
      expect(summary.insightMessage, isNotEmpty);
    });
  });

  group('BreathTrendEngine.summarize — trend direction thresholds', () {
    final engine = BreathTrendEngine();

    test('score improving by more than 10% is significantImprovement', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 40),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 40,
        ),
        _record(
          completedAt: base.add(const Duration(days: 20)),
          breathScore: 60,
        ),
        _record(
          completedAt: base.add(const Duration(days: 21)),
          breathScore: 60,
        ),
        _record(
          completedAt: base.add(const Duration(days: 22)),
          breathScore: 60,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');
      expect(summary.hasEnoughDataForTrend, isTrue);
      expect(summary.direction, BreathProgressDirection.significantImprovement);
      expect(summary.scoreChangeFirstWeekVsLastWeekPercent, greaterThan(10));
    });

    test('small change within +-3% is stable', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 50),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 50,
        ),
        _record(
          completedAt: base.add(const Duration(days: 20)),
          breathScore: 51,
        ),
        _record(
          completedAt: base.add(const Duration(days: 21)),
          breathScore: 50,
        ),
        _record(
          completedAt: base.add(const Duration(days: 22)),
          breathScore: 50,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');
      expect(summary.direction, BreathProgressDirection.stable);
    });

    test('decline beyond -3% uses a calm, non-alarming message', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 60),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 60,
        ),
        _record(
          completedAt: base.add(const Duration(days: 20)),
          breathScore: 40,
        ),
        _record(
          completedAt: base.add(const Duration(days: 21)),
          breathScore: 40,
        ),
        _record(
          completedAt: base.add(const Duration(days: 22)),
          breathScore: 40,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');
      expect(summary.direction, BreathProgressDirection.decline);
      expect(summary.insightMessage, contains('doktor'));
      // No blaming/alarming language.
      expect(summary.insightMessage.toLowerCase(), isNot(contains('kötü')));
    });
  });

  group('BreathTrendEngine.summarize — noisy records excluded', () {
    final engine = BreathTrendEngine();

    test('noisy records are excluded from window averages and best score', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 10, isNoisyEnvironment: true),
        _record(
          completedAt: base.add(const Duration(hours: 1)),
          breathScore: 90,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');
      // Only the clean (90) record should count toward the best score and
      // the 7-day window average — the noisy 10 must not drag it down.
      expect(summary.bestScore, 90);
      expect(summary.last7Days.testCount, 1);
      expect(summary.last7Days.averageScore, 90);
    });

    test('a noisy day is flagged in the chart but contributes no score', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 50, isNoisyEnvironment: true),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 60,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');
      final noisyPoint = summary.chartPoints.firstWhere(
        (p) => p.date == DateTime(2026, 1, 1),
      );
      expect(noisyPoint.hasSkippedNoisyTest, isTrue);
      expect(noisyPoint.rawScore, isNull);
    });
  });

  group('BreathTrendEngine.summarize — legacy schemaVersion excluded', () {
    final engine = BreathTrendEngine();

    test(
      'schemaVersion 1 (pre exhale-duration-fix) records are excluded from '
      'window averages and best score, same as noisy records '
      '(regression: old inflated blowDurationSeconds must not pollute the '
      'trend once the measurement bug is fixed)',
      () {
        final base = DateTime(2026, 1, 1);
        final records = [
          _record(completedAt: base, breathScore: 10, schemaVersion: 1),
          _record(
            completedAt: base.add(const Duration(hours: 1)),
            breathScore: 90,
          ),
        ];

        final summary = engine.summarize(records, languageCode: 'tr');
        expect(summary.bestScore, 90);
        expect(summary.last7Days.testCount, 1);
        expect(summary.last7Days.averageScore, 90);
      },
    );
  });

  group('BreathTrendEngine.summarize — chart moving average', () {
    final engine = BreathTrendEngine();

    test('moving average is only populated once 7 days of history exist', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        10,
        (i) =>
            _record(completedAt: base.add(Duration(days: i)), breathScore: 50),
      );

      final summary = engine.summarize(records, languageCode: 'tr');
      expect(summary.chartPoints.length, 10);
      // First 6 days (index 0-5) have fewer than 7 days of history.
      for (var i = 0; i < 6; i++) {
        expect(summary.chartPoints[i].movingAverageScore, isNull);
      }
      // From day 7 (index 6) onward, it should be populated.
      for (var i = 6; i < 10; i++) {
        expect(summary.chartPoints[i].movingAverageScore, isNotNull);
      }
    });
  });
}
