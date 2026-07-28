import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/behavior_engine.dart';
import 'package:no_smoke/models/breath_test_record.dart';
import 'package:no_smoke/models/survey_history.dart';
import 'package:no_smoke/models/task_history.dart';
import 'package:no_smoke/models/survey_record.dart';

void main() {
  group('BehaviorEngine', () {
    test('calculates trigger scores and risky triggers', () {
      final surveys = <SurveyHistory>[
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 1),
          packsPerDay: '1 paket',
          longestSmokeFreeDuration: 6,
          hardestHour: '20:00',
          hardestDay: 'Pazartesi',
          triggers: ['stres', 'arkadaşlar', 'kahve'],
          stressLevel: 7,
          riskScore: 60,
        ),
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 8),
          packsPerDay: '1 paketten az',
          longestSmokeFreeDuration: 8,
          hardestHour: '21:00',
          hardestDay: 'Çarşamba',
          triggers: ['stres', 'kahve'],
          stressLevel: 6,
          riskScore: 55,
        ),
      ];

      final engine = BehaviorEngine();
      final triggerScores = engine.calculateTriggerScores(surveys);
      final riskyTriggers = engine.calculateRiskyTriggers(triggerScores);

      expect(triggerScores['Stres'], 20);
      expect(triggerScores['Kahve'], 20);
      expect(riskyTriggers, contains('Stres'));
      expect(riskyTriggers, contains('Kahve'));
      expect(riskyTriggers, isNot(contains('Arkadaşlar')));
    });

    test('groups risky hours into windows', () {
      final surveys = <SurveyHistory>[
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 1),
          packsPerDay: '1 paket',
          longestSmokeFreeDuration: 6,
          hardestHour: '20:00',
          hardestDay: 'Pazartesi',
          triggers: ['stres'],
          stressLevel: 7,
          riskScore: 60,
        ),
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 8),
          packsPerDay: '1 paketten az',
          longestSmokeFreeDuration: 8,
          hardestHour: '20:30',
          hardestDay: 'Çarşamba',
          triggers: ['stres'],
          stressLevel: 6,
          riskScore: 55,
        ),
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 15),
          packsPerDay: '1 paketten az',
          longestSmokeFreeDuration: 9,
          hardestHour: '21:15',
          hardestDay: 'Perşembe',
          triggers: ['stres'],
          stressLevel: 5,
          riskScore: 50,
        ),
      ];

      final engine = BehaviorEngine();
      final riskyHours = engine.calculateRiskyHours(surveys);

      expect(riskyHours, contains('20:00-22:00'));
    });

    test('calculates task success rates and breath trend', () {
      final tasks = <TaskHistory>[
        TaskHistory(taskId: '1', taskTitle: 'Meditasyon', completed: true, date: DateTime(2024, 1, 1)),
        TaskHistory(taskId: '1', taskTitle: 'Meditasyon', completed: true, date: DateTime(2024, 1, 2)),
        TaskHistory(taskId: '1', taskTitle: 'Meditasyon', completed: false, date: DateTime(2024, 1, 3)),
        TaskHistory(taskId: '2', taskTitle: 'Yürüyüş', completed: false, date: DateTime(2024, 1, 4)),
      ];
      final breaths = <BreathTestRecord>[
        BreathTestRecord(date: DateTime(2024, 1, 1), exhaleSeconds: 12, inhaleSeconds: 10),
        BreathTestRecord(date: DateTime(2024, 1, 2), exhaleSeconds: 18, inhaleSeconds: 15),
      ];

      final engine = BehaviorEngine();
      final taskRates = engine.calculateTaskSuccessRates(tasks);
      final breathTrend = engine.calculateBreathTrend(breaths);

      final meditation = taskRates.firstWhere((item) => item['taskTitle'] == 'Meditasyon');
      expect(meditation['successRate'], 0.6666666666666666);
      expect(meditation['totalCount'], 3);
      expect(breathTrend, 'Improving');
    });

    test('generates a complete behavior profile', () {
      final surveys = <SurveyHistory>[
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 1),
          packsPerDay: '2 paket',
          longestSmokeFreeDuration: 6,
          hardestHour: '20:00',
          hardestDay: 'Pazartesi',
          triggers: ['stres', 'kahve'],
          stressLevel: 7,
          riskScore: 70,
        ),
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 8),
          packsPerDay: '1 paket',
          longestSmokeFreeDuration: 8,
          hardestHour: '20:30',
          hardestDay: 'Çarşamba',
          triggers: ['stres'],
          stressLevel: 5,
          riskScore: 55,
        ),
      ];
      final breaths = <BreathTestRecord>[
        BreathTestRecord(date: DateTime(2024, 1, 1), exhaleSeconds: 12, inhaleSeconds: 10),
        BreathTestRecord(date: DateTime(2024, 1, 8), exhaleSeconds: 14, inhaleSeconds: 12),
      ];
      final tasks = <TaskHistory>[
        TaskHistory(taskId: '1', taskTitle: 'Meditasyon', completed: true, date: DateTime(2024, 1, 1)),
        TaskHistory(taskId: '1', taskTitle: 'Meditasyon', completed: false, date: DateTime(2024, 1, 2)),
      ];

      final engine = BehaviorEngine();
      final profile = engine.generateBehaviorProfile(
        surveys: surveys,
        breathTests: breaths,
        taskHistory: tasks,
      );

      expect(profile.riskScore, greaterThanOrEqualTo(0));
      expect(profile.riskyTriggers, isNotEmpty);
      expect(profile.progressStatus, isA<String>());
      expect(profile.breathTrend, isA<String>());
    });

    test('calculates consecutive smoking score and trend', () {
      final engine = BehaviorEngine();
      final score = engine.calculateConsecutiveSmokingScore(
        habit: 'Evet, sık sık',
        count: '5+ adet',
      );

      expect(score, 20);

      final trend = engine.evaluateConsecutiveSmokingTrend(
        previousHabit: 'Evet, sık sık',
        previousCount: '4 adet',
        currentHabit: 'Evet, bazen',
        currentCount: '2 adet',
      );

      expect(trend, 'trendImproving');

      final summary = engine.summarizeConsecutiveSmoking(
        habit: 'Evet, bazen',
        count: '3 adet',
      );

      expect(summary, 'Evet, bazen - 3 adet');
    });

    test('generates consecutive smoking fields in behavior profile', () {
      final engine = BehaviorEngine();
      final profile = engine.generateBehaviorProfile(
        surveys: const [],
        breathTests: const [],
        taskHistory: const [],
        surveyRecords: [
          SurveyRecord(
            id: '1',
            completedAt: DateTime(2024, 1, 1),
            type: 'initial',
            title: 'Başlangıç Anketi',
            name: 'Ada',
            packsPerDay: '2 paket',
            exhaleTestSeconds: 0,
            inhaleTestSeconds: 0,
            riskScore: 40,
            riskLevel: 'ORTA',
            consecutiveSmokingHabit: 'Evet, bazen',
            consecutiveSmokingCount: '4 adet',
          ),
          SurveyRecord(
            id: '2',
            completedAt: DateTime(2024, 1, 8),
            type: 'weekly',
            title: 'Haftalık Anket',
            name: 'Ada',
            packsPerDay: '1 paket',
            exhaleTestSeconds: 0,
            inhaleTestSeconds: 0,
            riskScore: 35,
            riskLevel: 'ORTA',
            consecutiveSmokingHabit: 'Evet, bazen',
            consecutiveSmokingCount: '3 adet',
          ),
        ],
      );

      expect(profile.consecutiveSmokingTrend, 'trendImproving');
      expect(profile.consecutiveSmokingStatus, 'Evet, bazen - 3 adet');
      expect(profile.riskTrend, 'Stable');
      expect(profile.suggestedTasks, isNotEmpty);

      final summary = engine.buildHomeSummary(profile);
      expect(summary['consecutiveSmokingTrend'], 'trendImproving');
      expect(summary['consecutiveSmokingStatus'], 'Evet, bazen - 3 adet');
      expect(summary['suggestedTasks'], isA<List<String>>());
    });

    test('calculates consecutive smoking trend from survey history', () {
      final engine = BehaviorEngine();
      final trend = engine.calculateConsecutiveSmokingTrend([
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 1),
          packsPerDay: '3 paket',
          longestSmokeFreeDuration: 6,
          hardestHour: '20:00',
          hardestDay: 'Pazartesi',
          triggers: ['stres'],
          stressLevel: 7,
          riskScore: 60,
          chainSmokingLevel: '5+ adet',
          consecutiveSmokingHabit: 'Evet, sık sık',
          consecutiveSmokingCount: '5+ adet',
        ),
        SurveyHistory(
          surveyDate: DateTime(2024, 1, 8),
          packsPerDay: '2 paket',
          longestSmokeFreeDuration: 8,
          hardestHour: '21:00',
          hardestDay: 'Çarşamba',
          triggers: ['stres'],
          stressLevel: 6,
          riskScore: 55,
          chainSmokingLevel: '3 adet',
          consecutiveSmokingHabit: 'Evet, bazen',
          consecutiveSmokingCount: '3 adet',
        ),
      ]);

      expect(trend, 'trendImproving');
    });

    group('risky hours', () {
      final engine = BehaviorEngine();

      List<DateTime> at(int hour, {int count = 1}) => List.generate(
        count,
        (i) => DateTime(2026, 7, 20 - i, hour, 15),
      );

      test('logged cigarettes decide the top window over proxy signals', () {
        final hours = engine.calculateRiskyHoursFromTimestamps(
          // Proxies all pointing at the morning...
          surveyTimes: at(9, count: 4),
          appUsageTimes: at(9, count: 4),
          breathTestTimes: at(9, count: 4),
          taskFailureTimes: at(9, count: 2),
          // ...but the user actually reported smoking in the evening.
          smokingTimes: at(20, count: 4),
        );

        expect(hours.first, contains('20'));
      });

      test('still works when nothing has been logged', () {
        final hours = engine.calculateRiskyHoursFromTimestamps(
          surveyTimes: at(9, count: 3),
          appUsageTimes: const [],
          taskFailureTimes: const [],
          breathTestTimes: const [],
        );

        expect(hours, isNotEmpty);
      });

      test('a single logged cigarette outweighs one failed task', () {
        final hours = engine.calculateRiskyHoursFromTimestamps(
          surveyTimes: const [],
          appUsageTimes: const [],
          taskFailureTimes: at(11),
          breathTestTimes: const [],
          smokingTimes: at(16),
        );

        expect(hours.first, contains('16'));
      });
    });
  });
}
