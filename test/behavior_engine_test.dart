import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/behavior_engine.dart';
import 'package:no_smoke/models/breath_test_record.dart';
import 'package:no_smoke/models/cough_test_record.dart';
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
        TaskHistory(
          taskId: '1',
          taskTitle: 'Meditasyon',
          completed: true,
          date: DateTime(2024, 1, 1),
        ),
        TaskHistory(
          taskId: '1',
          taskTitle: 'Meditasyon',
          completed: true,
          date: DateTime(2024, 1, 2),
        ),
        TaskHistory(
          taskId: '1',
          taskTitle: 'Meditasyon',
          completed: false,
          date: DateTime(2024, 1, 3),
        ),
        TaskHistory(
          taskId: '2',
          taskTitle: 'Yürüyüş',
          completed: false,
          date: DateTime(2024, 1, 4),
        ),
      ];
      final breaths = <BreathTestRecord>[
        BreathTestRecord(
          date: DateTime(2024, 1, 1),
          exhaleSeconds: 12,
          inhaleSeconds: 10,
        ),
        BreathTestRecord(
          date: DateTime(2024, 1, 2),
          exhaleSeconds: 18,
          inhaleSeconds: 15,
        ),
      ];

      final engine = BehaviorEngine();
      final taskRates = engine.calculateTaskSuccessRates(tasks);
      final breathTrend = engine.calculateBreathTrend(breaths);

      final meditation = taskRates.firstWhere(
        (item) => item['taskTitle'] == 'Meditasyon',
      );
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
        BreathTestRecord(
          date: DateTime(2024, 1, 1),
          exhaleSeconds: 12,
          inhaleSeconds: 10,
        ),
        BreathTestRecord(
          date: DateTime(2024, 1, 8),
          exhaleSeconds: 14,
          inhaleSeconds: 12,
        ),
      ];
      final tasks = <TaskHistory>[
        TaskHistory(
          taskId: '1',
          taskTitle: 'Meditasyon',
          completed: true,
          date: DateTime(2024, 1, 1),
        ),
        TaskHistory(
          taskId: '1',
          taskTitle: 'Meditasyon',
          completed: false,
          date: DateTime(2024, 1, 2),
        ),
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

    test('orders time-series records before calculating trends', () {
      final engine = BehaviorEngine();
      final older = SurveyHistory(
        surveyDate: DateTime(2024, 1, 1),
        packsPerDay: '2 paket',
        longestSmokeFreeDuration: 6,
        hardestHour: '20:00',
        hardestDay: 'Pazartesi',
        triggers: const ['stres'],
        stressLevel: 7,
        riskScore: 70,
        chainSmokingLevel: '5+ adet',
      );
      final newer = SurveyHistory(
        surveyDate: DateTime(2024, 1, 8),
        packsPerDay: '1 paket',
        longestSmokeFreeDuration: 8,
        hardestHour: '21:00',
        hardestDay: 'Çarşamba',
        triggers: const ['stres'],
        stressLevel: 5,
        riskScore: 40,
        chainSmokingLevel: '2 adet',
      );

      expect(engine.calculateSmokingTrend([newer, older]), 'Decreasing');
      expect(engine.calculateRiskTrend([newer, older]), 'Improving');
      expect(
        engine.calculateConsecutiveSmokingTrend([newer, older]),
        'trendImproving',
      );
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

      List<DateTime> at(int hour, {int count = 1}) =>
          List.generate(count, (i) => DateTime(2026, 7, 20 - i, hour, 15));

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

    group('calculateCoughRiskAdjustment', () {
      final engine = BehaviorEngine();

      CoughTestRecord record(String severityLevel) => CoughTestRecord(
        id: 'r',
        createdAt: DateTime(2024, 1, 1),
        coughCount: 0,
        testDurationSeconds: 30,
        severityScore: 0,
        severityLevel: severityLevel,
      );

      test('no records means no adjustment', () {
        expect(engine.calculateCoughRiskAdjustment(recentRecords: const []), 0);
      });

      test('a normal latest result nudges risk down slightly', () {
        expect(
          engine.calculateCoughRiskAdjustment(
            recentRecords: [record('normal')],
          ),
          -2,
        );
      });

      test('mild adds a small positive adjustment', () {
        expect(
          engine.calculateCoughRiskAdjustment(recentRecords: [record('mild')]),
          1,
        );
      });

      test('moderate adds more than mild', () {
        expect(
          engine.calculateCoughRiskAdjustment(
            recentRecords: [record('moderate')],
          ),
          4,
        );
      });

      test('severe adds the most', () {
        expect(
          engine.calculateCoughRiskAdjustment(
            recentRecords: [record('severe')],
          ),
          8,
        );
      });

      test('only the most recent record is used', () {
        final adjustment = engine.calculateCoughRiskAdjustment(
          recentRecords: [record('severe'), record('normal')],
        );
        expect(adjustment, -2);
      });
    });

    group('calculateSnoringRiskAdjustment', () {
      final engine = BehaviorEngine();

      test('zero probes means no adjustment', () {
        expect(
          engine.calculateSnoringRiskAdjustment(recentSnoreLikelyCount: 0),
          0,
        );
      });

      test('1-3 probes is a small adjustment', () {
        expect(
          engine.calculateSnoringRiskAdjustment(recentSnoreLikelyCount: 2),
          1,
        );
      });

      test('4-9 probes is a moderate adjustment', () {
        expect(
          engine.calculateSnoringRiskAdjustment(recentSnoreLikelyCount: 5),
          3,
        );
      });

      test('10+ probes is the largest adjustment', () {
        expect(
          engine.calculateSnoringRiskAdjustment(recentSnoreLikelyCount: 15),
          6,
        );
      });
    });

    group('resolveCoughAdvisoryTier', () {
      final engine = BehaviorEngine();

      test(
        'baseline severity with no conditions or history passes through',
        () {
          expect(
            engine.resolveCoughAdvisoryTier(
              latestSeverityLevel: 'mild',
              healthConditions: const [],
              recentModerateOrWorseCountLast14Days: 0,
            ),
            'mild',
          );
        },
      );

      test('normal stays normal even with a chronic condition', () {
        // The bump only applies once the baseline is already mild+ — a
        // clean test shouldn't get escalated just for having COPD on file.
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'normal',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'normal',
        );
      });

      test('a respiratory condition bumps a mild+ result up one tier', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'mild',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'moderate',
        );
      });

      test('asthma also triggers the bump', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'moderate',
            healthConditions: const ['Astim'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'severe',
        );
      });

      test('a non-respiratory condition does not bump the tier', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'mild',
            healthConditions: const ['Hipertansiyon'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'mild',
        );
      });

      test('the bump never pushes severe past urgent', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'severe',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'urgent',
        );
      });

      test('three or more moderate-plus results in 14 days forces urgent', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'mild',
            healthConditions: const [],
            recentModerateOrWorseCountLast14Days: 3,
          ),
          'urgent',
        );
      });

      test('two moderate-plus results in 14 days does not force urgent', () {
        expect(
          engine.resolveCoughAdvisoryTier(
            latestSeverityLevel: 'mild',
            healthConditions: const [],
            recentModerateOrWorseCountLast14Days: 2,
          ),
          'mild',
        );
      });
    });

    group('resolveWheezeAdvisoryTier', () {
      final engine = BehaviorEngine();

      test(
        'baseline severity with no conditions or history passes through',
        () {
          expect(
            engine.resolveWheezeAdvisoryTier(
              latestWheezeSeverityLevel: 'mild',
              healthConditions: const [],
              recentModerateOrWorseCountLast14Days: 0,
            ),
            'mild',
          );
        },
      );

      test('none stays none even with a chronic condition', () {
        expect(
          engine.resolveWheezeAdvisoryTier(
            latestWheezeSeverityLevel: 'none',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'none',
        );
      });

      test('a respiratory condition bumps a mild+ result up one tier', () {
        expect(
          engine.resolveWheezeAdvisoryTier(
            latestWheezeSeverityLevel: 'mild',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'moderate',
        );
      });

      test('asthma also triggers the bump', () {
        expect(
          engine.resolveWheezeAdvisoryTier(
            latestWheezeSeverityLevel: 'moderate',
            healthConditions: const ['Astim'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'severe',
        );
      });

      test('a non-respiratory condition does not bump the tier', () {
        expect(
          engine.resolveWheezeAdvisoryTier(
            latestWheezeSeverityLevel: 'mild',
            healthConditions: const ['Hipertansiyon'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'mild',
        );
      });

      test('the bump never pushes past severe (top tier clamp)', () {
        expect(
          engine.resolveWheezeAdvisoryTier(
            latestWheezeSeverityLevel: 'severe',
            healthConditions: const ['KOAH'],
            recentModerateOrWorseCountLast14Days: 0,
          ),
          'severe',
        );
      });

      test(
        'three or more moderate-plus results in 14 days forces the top tier',
        () {
          expect(
            engine.resolveWheezeAdvisoryTier(
              latestWheezeSeverityLevel: 'mild',
              healthConditions: const [],
              recentModerateOrWorseCountLast14Days: 3,
            ),
            'severe',
          );
        },
      );

      test(
        'two moderate-plus results in 14 days does not force the top tier',
        () {
          expect(
            engine.resolveWheezeAdvisoryTier(
              latestWheezeSeverityLevel: 'mild',
              healthConditions: const [],
              recentModerateOrWorseCountLast14Days: 2,
            ),
            'mild',
          );
        },
      );
    });
  });
}
