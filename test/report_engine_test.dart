import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/report_engine.dart';
import 'package:no_smoke/models/smoking_event.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/models/task_history.dart';

SurveyRecord _survey({
  required DateTime completedAt,
  required String type,
  required int riskScore,
  DateTime? quitDate,
}) {
  return SurveyRecord(
    id: 'r_${completedAt.millisecondsSinceEpoch}',
    completedAt: completedAt,
    type: type,
    title: 'Anket',
    name: 'Test',
    packsPerDay: '1 paket',
    exhaleTestSeconds: 10,
    inhaleTestSeconds: 10,
    riskScore: riskScore,
    riskLevel: 'medium',
    quitDate: quitDate,
  );
}

void main() {
  group('ReportEngine.buildReport', () {
    final engine = ReportEngine();
    final periodStart = DateTime(2026, 7, 1);
    final periodEnd = DateTime(2026, 7, 8);

    test('computes risk trend and counts from records inside the period '
        'only', () {
      final records = [
        _survey(
          completedAt: DateTime(2026, 6, 20),
          type: 'initial',
          riskScore: 90,
        ), // before period, must be excluded
        _survey(
          completedAt: DateTime(2026, 7, 2),
          type: 'initial',
          riskScore: 70,
        ),
        _survey(
          completedAt: DateTime(2026, 7, 5),
          type: 'weekly',
          riskScore: 55,
        ),
        _survey(
          completedAt: DateTime(2026, 7, 10),
          type: 'weekly',
          riskScore: 10,
        ), // after period, must be excluded
      ];

      final report = engine.buildReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        periodType: 'weekly',
        allSurveyRecords: records,
        allTaskHistory: const [],
        smokingEventsInPeriod: const [],
      );

      expect(report.riskScoreAtStart, 70);
      expect(report.riskScoreAtEnd, 55);
      expect(report.riskTrend, 'Improving');
      expect(report.weeklySurveysCompleted, 1);
    });

    test('computes task completion rate only from tasks inside the period', () {
      final tasks = [
        TaskHistory(
          taskId: 't1',
          taskTitle: 'A',
          completed: true,
          date: DateTime(2026, 7, 3),
        ),
        TaskHistory(
          taskId: 't2',
          taskTitle: 'B',
          completed: false,
          date: DateTime(2026, 7, 4),
        ),
        TaskHistory(
          taskId: 't3',
          taskTitle: 'C',
          completed: true,
          date: DateTime(2026, 6, 15),
        ), // outside period
      ];

      final report = engine.buildReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        periodType: 'weekly',
        allSurveyRecords: const [],
        allTaskHistory: tasks,
        smokingEventsInPeriod: const [],
      );

      expect(report.taskSuccessCount, 1);
      expect(report.taskFailureCount, 1);
      expect(report.taskCompletionRate, 0.5);
    });

    test('averages cigarettes logged over the period length', () {
      final events = List.generate(
        14,
        (i) => SmokingEvent(
          id: 'e$i',
          timestamp: periodStart.add(Duration(hours: i * 6)),
          source: 'quick_log',
          approximate: false,
        ),
      );

      final report = engine.buildReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        periodType: 'weekly',
        allSurveyRecords: const [],
        allTaskHistory: const [],
        smokingEventsInPeriod: events,
      );

      expect(report.cigarettesLogged, 14);
      expect(report.avgCigarettesPerDay, 2.0);
    });

    test('resolves the earliest quit date across all records for '
        'days-since-quit', () {
      final records = [
        _survey(
          completedAt: DateTime(2026, 7, 2),
          type: 'initial',
          riskScore: 50,
          quitDate: DateTime(2026, 6, 1),
        ),
        _survey(
          completedAt: DateTime(2026, 7, 5),
          type: 'weekly',
          riskScore: 40,
          quitDate: DateTime(2026, 6, 10),
        ),
      ];

      final report = engine.buildReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        periodType: 'weekly',
        allSurveyRecords: records,
        allTaskHistory: const [],
        smokingEventsInPeriod: const [],
      );

      expect(report.daysSinceQuitDate, isNotNull);
      expect(
        report.daysSinceQuitDate,
        DateTime.now().difference(DateTime(2026, 6, 1)).inDays,
      );
    });
  });
}
