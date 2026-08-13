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
    );
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
