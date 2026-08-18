import '../models/period_report.dart';
import '../models/smoking_event.dart';
import '../models/step_counter_sample.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../services/behavior_engine.dart';
import 'step_trend_engine.dart';

/// Aggregates already-collected data (survey records, task history, quick
/// smoking logs) into a [PeriodReport] for a given week or month. Pure and
/// DB-free like the other engines — reuses `BehaviorEngine`'s existing
/// breath/smoking trend calculators instead of re-deriving them, so this
/// stays consistent with the risk dashboard rather than being a second,
/// slightly-different source of truth for the same trends.
class ReportEngine {
  final BehaviorEngine _behaviorEngine;
  final StepTrendEngine _stepTrendEngine;

  ReportEngine({
    BehaviorEngine? behaviorEngine,
    StepTrendEngine? stepTrendEngine,
  }) : _behaviorEngine = behaviorEngine ?? BehaviorEngine(),
       _stepTrendEngine = stepTrendEngine ?? StepTrendEngine();

  PeriodReport buildReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String periodType,
    required List<SurveyRecord> allSurveyRecords,
    required List<TaskHistory> allTaskHistory,
    required List<SmokingEvent> smokingEventsInPeriod,
    List<StepCounterSample> stepSamples = const [],
  }) {
    final recordsInPeriod =
        allSurveyRecords
            .where(
              (record) =>
                  !record.completedAt.isBefore(periodStart) &&
                  record.completedAt.isBefore(periodEnd),
            )
            .toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final surveysInPeriod = recordsInPeriod
        .where((record) => record.type == 'initial' || record.type == 'weekly')
        .toList();
    final breathTestsInPeriod = recordsInPeriod
        .where((record) => record.type == 'breath_test')
        .toList();

    final riskAtStart = surveysInPeriod.isEmpty
        ? null
        : surveysInPeriod.first.riskScore;
    final riskAtEnd = surveysInPeriod.isEmpty
        ? null
        : surveysInPeriod.last.riskScore;
    final riskTrend = _resolveRiskTrend(riskAtStart, riskAtEnd);

    final tasksInPeriod = allTaskHistory
        .where(
          (task) =>
              !task.date.isBefore(periodStart) && task.date.isBefore(periodEnd),
        )
        .toList();
    final taskSuccessCount = tasksInPeriod
        .where((task) => task.completed)
        .length;
    final taskFailureCount = tasksInPeriod.length - taskSuccessCount;
    final taskCompletionRate = tasksInPeriod.isEmpty
        ? 0.0
        : taskSuccessCount / tasksInPeriod.length;

    final periodDays = periodEnd.difference(periodStart).inDays.clamp(1, 366);
    final avgCigarettesPerDay = smokingEventsInPeriod.length / periodDays;

    // Calendar days since the date the user named, nothing more — it does
    // not know whether they smoked on any of them. The label says exactly
    // that now; it used to read "smoke-free days", which it never was.
    final quitDate = _earliestQuitDate(allSurveyRecords);
    final daysSinceQuitDate = quitDate == null
        ? null
        : DateTime.now().difference(quitDate).inDays;

    final totalSteps = _stepTrendEngine.totalStepsInRange(
      stepSamples,
      start: periodStart,
      end: periodEnd,
    );
    final avgStepsPerDay = totalSteps / periodDays;

    final baselineAvgPerDay = _baselineAveragePerDay(
      allSurveyRecords,
      periodStart,
    );
    // Absence of quick-log data this period is not evidence of quitting —
    // it just as easily means the user never opened the quick-log button.
    // Treating an empty smokingEventsInPeriod the same as "zero cigarettes"
    // used to report the full baseline average as cigarettes averted (e.g.
    // "140 cigarettes not smoked" for a baseline-20/day user who simply
    // didn't log anything that week), the exact inversion this field's own
    // "never invented" doc comment promises against.
    final estimatedAvertedCigarettes =
        (baselineAvgPerDay == null || smokingEventsInPeriod.isEmpty)
        ? null
        : _estimatedAverted(baselineAvgPerDay, avgCigarettesPerDay, periodDays);

    return PeriodReport(
      periodStart: periodStart,
      periodEnd: periodEnd,
      periodType: periodType,
      cigarettesLogged: smokingEventsInPeriod.length,
      avgCigarettesPerDay: avgCigarettesPerDay,
      riskScoreAtStart: riskAtStart,
      riskScoreAtEnd: riskAtEnd,
      riskTrend: riskTrend,
      breathTrend: _behaviorEngine.calculateBreathTrendFromRecords(
        breathTestsInPeriod.isEmpty ? recordsInPeriod : breathTestsInPeriod,
      ),
      smokingTrend: _behaviorEngine.calculateSmokingTrendFromRecords(
        recordsInPeriod,
      ),
      taskSuccessCount: taskSuccessCount,
      taskFailureCount: taskFailureCount,
      taskCompletionRate: taskCompletionRate,
      weeklySurveysCompleted: recordsInPeriod
          .where((record) => record.type == 'weekly')
          .length,
      breathTestsCompleted: breathTestsInPeriod.length,
      daysSinceQuitDate: daysSinceQuitDate,
      totalSteps: totalSteps,
      avgStepsPerDay: avgStepsPerDay,
      estimatedAvertedCigarettes: estimatedAvertedCigarettes,
      smokingTimePattern: _smokingTimePattern(smokingEventsInPeriod),
    );
  }

  /// Best-guess average daily smoking count before the period started,
  /// derived only from real survey records (the lowest baseline the user
  /// reported across their surveys). Null when there is nothing real to
  /// base it on.
  double? _baselineAveragePerDay(
    List<SurveyRecord> allSurveyRecords,
    DateTime periodStart,
  ) {
    double? baseline;
    for (final record in allSurveyRecords) {
      if (!record.completedAt.isBefore(periodStart)) {
        continue;
      }
      final count = SurveyRecord.packsToLegacyCigarettes(record.packsPerDay);
      if (baseline == null || count < baseline) {
        baseline = count.toDouble();
      }
    }
    return baseline;
  }

  int _estimatedAverted(
    double baselineAvgPerDay,
    double currentAvgPerDay,
    int periodDays,
  ) {
    final diff = baselineAvgPerDay - currentAvgPerDay;
    if (diff <= 0) {
      return 0;
    }
    return (diff * periodDays).round();
  }

  /// Share of logged cigarettes per part of the day. Null unless there are
  /// at least 3 real events — below that there is no pattern to report.
  Map<String, double>? _smokingTimePattern(List<SmokingEvent> events) {
    if (events.length < 3) {
      return null;
    }
    final buckets = <String, double>{
      'morning': 0.0,
      'midday': 0.0,
      'afternoon': 0.0,
      'evening': 0.0,
      'night': 0.0,
    };
    for (final event in events) {
      final part = _partOfDay(event.timestamp.hour);
      final current = buckets[part] ?? 0;
      buckets[part] = current + 1;
    }
    final total = events.length.toDouble();
    return buckets.map((key, value) => MapEntry(key, value / total));
  }

  String _partOfDay(int hour) {
    if (hour >= 5 && hour < 10) {
      return 'morning';
    }
    if (hour >= 10 && hour < 13) {
      return 'midday';
    }
    if (hour >= 13 && hour < 17) {
      return 'afternoon';
    }
    if (hour >= 17 && hour < 22) {
      return 'evening';
    }
    return 'night';
  }

  String _resolveRiskTrend(int? start, int? end) {
    if (start == null || end == null) {
      return 'Stable';
    }
    if (end < start) {
      return 'Improving';
    }
    if (end > start) {
      return 'Declining';
    }
    return 'Stable';
  }

  DateTime? _earliestQuitDate(List<SurveyRecord> records) {
    DateTime? earliest;
    for (final record in records) {
      final quitDate = record.quitDate;
      if (quitDate == null) {
        continue;
      }
      if (earliest == null || quitDate.isBefore(earliest)) {
        earliest = quitDate;
      }
    }
    return earliest;
  }
}
