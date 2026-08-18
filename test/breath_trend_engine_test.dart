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

    test('different plausible blow durations produce different scores '
        '(regression: with real exhale-only durations, the old 15s ceiling '
        'combined with the old inflated-duration bug meant every attempt '
        'saturated the duration signal to 1.0)', () {
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
    });
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
      // Within the real last7Days window (see the window-anchoring group
      // below), not a fixed historical date — last7Days is now anchored to
      // DateTime.now(), not the record set's own last timestamp.
      final base = DateTime.now().subtract(const Duration(hours: 2));
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

    test('schemaVersion 1 (pre exhale-duration-fix) records are excluded from '
        'window averages and best score, same as noisy records '
        '(regression: old inflated blowDurationSeconds must not pollute the '
        'trend once the measurement bug is fixed)', () {
      final base = DateTime.now().subtract(const Duration(hours: 2));
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
    });
  });

  group(
    'BreathTrendEngine.summarize — window anchoring (regression coverage)',
    () {
      final engine = BreathTrendEngine();

      // Regression coverage: last7Days/last30Days/last90Days used to anchor
      // "now" to the *last record's* timestamp (sorted.last.completedAt),
      // not the actual current wall-clock time. A user who stopped testing
      // 5 months ago and reopens the analysis page would see "last 30 days:
      // 12 tests, 72% consistency" computed against their final active
      // month — a stale month made to look like the present.
      test('a user inactive for 5 months does not see a recent-activity window '
          'built from that stale burst', () {
        final fiveMonthsAgo = DateTime.now().subtract(
          const Duration(days: 150),
        );
        final records = List.generate(
          12,
          (i) => _record(
            completedAt: fiveMonthsAgo.add(Duration(days: i)),
            breathScore: 70,
          ),
        );

        final summary = engine.summarize(records, languageCode: 'tr');

        // None of these 12 tests happened in the real last 7/30 days —
        // every window must read as empty, not as "12 tests this month".
        expect(summary.last7Days.testCount, 0);
        expect(summary.last30Days.testCount, 0);
        expect(summary.last90Days.testCount, 0);
      });

      test('a test taken today is correctly counted in every window, '
          'regardless of when earlier tests happened', () {
        final longAgo = DateTime.now().subtract(const Duration(days: 200));
        final records = [
          _record(completedAt: longAgo, breathScore: 50),
          _record(completedAt: DateTime.now(), breathScore: 80),
        ];

        final summary = engine.summarize(records, languageCode: 'tr');

        expect(summary.last7Days.testCount, 1);
        expect(summary.last7Days.averageScore, 80);
      });
    },
  );

  group('BreathTrendEngine.summarize — chart day stepping', () {
    final engine = BreathTrendEngine();

    // Regression coverage: _buildChartPoints used to step through days with
    // cursor.add(const Duration(days: 1)) — a fixed 24h jump. On a DST
    // transition day in local time, that lands on 23:00 or 01:00 instead of
    // the next midnight, which then never matches any _dateOnly() key and
    // silently drops that day (and, since the drift compounds, every day
    // after it) from the chart. DateTime(y, m, d+1) is used instead, which
    // Dart normalizes as a calendar construction regardless of any
    // wall-clock DST jump — this test proves that normalization directly
    // (month-end rollover is the simplest reliable case a unit test can
    // exercise without depending on the host machine's own timezone/DST
    // rules) rather than simulating a specific real-world transition date.
    test('every day in the record span produces exactly one chart point, '
        'including a month boundary', () {
      final base = DateTime(2026, 1, 30);
      final records = [
        _record(completedAt: base, breathScore: 50),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 50,
        ),
        _record(
          completedAt: base.add(const Duration(days: 2)),
          breathScore: 50,
        ),
        _record(
          completedAt: base.add(const Duration(days: 3)),
          breathScore: 50,
        ),
      ];

      final summary = engine.summarize(records, languageCode: 'tr');

      expect(summary.chartPoints.length, 4);
      expect(summary.chartPoints.map((p) => p.date).toList(), [
        DateTime(2026, 1, 30),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 2),
      ]);
    });
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
