import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/behavior_engine.dart';
import 'package:no_smoke/models/adaptive_plan.dart';
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

    test(
      'reports confidence, freshness, recovery mode and suggestion reasons',
      () {
        final engine = BehaviorEngine();
        final surveys = List.generate(
          3,
          (index) => SurveyHistory(
            surveyDate: DateTime.now().subtract(Duration(days: index)),
            packsPerDay: '1 paket',
            longestSmokeFreeDuration: 8,
            hardestHour: '20:00',
            hardestDay: 'Pazartesi',
            triggers: const ['stres'],
            stressLevel: 5,
            riskScore: 40,
          ),
        );
        final tasks = List.generate(
          5,
          (index) => TaskHistory(
            taskId: '$index',
            taskTitle: 'Kısa yürüyüş',
            completed: index < 2,
            date: DateTime.now().subtract(Duration(days: index)),
          ),
        );
        final profile = engine.generateBehaviorProfile(
          surveys: surveys,
          breathTests: const [],
          taskHistory: tasks,
        );

        expect(profile.dataConfidence, 'high');
        expect(profile.dataFreshness, 'fresh');
        expect(profile.recoveryMode, 'relapseRisk');
        expect(profile.suggestionReasons, contains('trigger_risk'));
        expect(profile.suggestionReasons, contains('relapse_recovery'));
        expect(engine.buildHomeSummary(profile)['recoveryMode'], 'relapseRisk');
      },
    );

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

    test('finds repeated smoking places and ignores unavailable locations', () {
      final engine = BehaviorEngine();

      final places = engine.findRepeatedSmokingPlaceIds([
        'home',
        null,
        'work',
        'home',
        '',
        'work',
        'work',
      ]);

      expect(places, ['work', 'home']);
    });

    group('habit-sensitive adaptive tasks', () {
      final engine = BehaviorEngine();

      test(
        'prioritizes trigger-management task for an easy high-risk user',
        () {
          final tasks = engine.generateAdaptiveTasks(
            riskScore: 80,
            taskSuccessRates: const {},
            count: 1,
            riskyTriggers: const ['Kahve'],
          );

          expect(tasks, ['Kriz anini not et']);
        },
      );

      test('prioritizes risky-hour task for a medium-risk user', () {
        final tasks = engine.generateAdaptiveTasks(
          riskScore: 50,
          taskSuccessRates: const {},
          count: 1,
          riskyHours: const ['18:00-20:00'],
        );

        expect(tasks, ['Riskli saatte seker sakiz kullan']);
      });

      test('uses support task when recent smoking is frequent', () {
        final tasks = engine.generateAdaptiveTasks(
          riskScore: 20,
          taskSuccessRates: const {},
          count: 1,
          recentSmokingCount: 7,
        );

        expect(tasks, ['Aksam saatinde destek kisisiyle iletisim kur']);
      });
    });

    group('first-profile task', () {
      final engine = BehaviorEngine();

      // A brand-new profile's very first task used to be a hardcoded
      // Turkish sentence (regression coverage for that): it now returns a
      // canonical DELAY_FIRST_CIGARETTE:{minutes} code, which
      // AppTexts.localizeCanonicalTextForCode resolves per user language —
      // see delayFirstCigaretteTemplate in app_texts.dart.
      test('delays by 10 minutes for a high-risk first profile', () {
        final tasks = engine.generateAdaptiveTasks(
          riskScore: 80,
          taskSuccessRates: const {},
          isFirstProfile: true,
        );

        expect(tasks, ['DELAY_FIRST_CIGARETTE:10']);
      });

      test('delays by 20 minutes for a medium-risk first profile', () {
        final tasks = engine.generateAdaptiveTasks(
          riskScore: 50,
          taskSuccessRates: const {},
          isFirstProfile: true,
        );

        expect(tasks, ['DELAY_FIRST_CIGARETTE:20']);
      });

      test('delays by 45 minutes for a low-risk first profile', () {
        final tasks = engine.generateAdaptiveTasks(
          riskScore: 10,
          taskSuccessRates: const {},
          isFirstProfile: true,
        );

        expect(tasks, ['DELAY_FIRST_CIGARETTE:45']);
      });
    });

    group('buildRiskExplanation', () {
      final engine = BehaviorEngine();

      // Regression coverage: this used to return hardcoded Turkish
      // sentences with the numbers interpolated directly, which got
      // persisted to behavior_snapshot and shown under a translated title
      // in every language. It now returns canonical RISK_*:{score} codes —
      // AppTexts.localizeCanonicalTextForCode resolves each one.
      test('returns canonical codes with the signed deltas embedded', () {
        final lines = engine.buildRiskExplanation(
          baseRisk: 40,
          dynamicCoreRisk: 44,
          personalizedAdjustment: -5,
          profileAdjustment: 3,
          taskAdjustment: -2,
          finalRisk: 40,
        );

        expect(lines, [
          'RISK_BASE:40',
          'RISK_BEHAVIOR_DELTA:+4',
          'RISK_PERSONALIZED_DELTA:-5',
          'RISK_PROFILE_DELTA:+3',
          'RISK_TASK_DELTA:-2',
          'RISK_FINAL:40',
        ]);
      });

      test('a zero delta has no leading sign', () {
        final lines = engine.buildRiskExplanation(
          baseRisk: 50,
          dynamicCoreRisk: 50,
          personalizedAdjustment: 0,
          profileAdjustment: 0,
          taskAdjustment: 0,
          finalRisk: 50,
        );

        expect(lines[1], 'RISK_BEHAVIOR_DELTA:0');
        expect(lines[2], 'RISK_PERSONALIZED_DELTA:0');
        expect(lines[3], 'RISK_PROFILE_DELTA:0');
        expect(lines[4], 'RISK_TASK_DELTA:0');
      });
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

    group('resolveCoachCommandNotificationLimit', () {
      final engine = BehaviorEngine();

      test('a fresh user with no history gets the full burst', () {
        expect(
          engine.resolveCoachCommandNotificationLimit(
            recentSuccessCount: 0,
            recentFailureCount: 0,
            riskScore: 50,
          ),
          3,
        );
      });

      test(
        'consistently missing tasks with risk not yet elevated suppresses the burst entirely',
        () {
          expect(
            engine.resolveCoachCommandNotificationLimit(
              recentSuccessCount: 0,
              recentFailureCount: 4,
              riskScore: 69,
            ),
            0,
          );
        },
      );

      test('the same failure gap does not suppress once risk crosses 70', () {
        expect(
          engine.resolveCoachCommandNotificationLimit(
            recentSuccessCount: 0,
            recentFailureCount: 4,
            riskScore: 70,
          ),
          greaterThan(0),
        );
      });

      test(
        'failing more than succeeding by a smaller margin trims one push',
        () {
          expect(
            engine.resolveCoachCommandNotificationLimit(
              recentSuccessCount: 0,
              recentFailureCount: 3,
              riskScore: 50,
            ),
            2,
          );
        },
      );

      test('a strong success streak also trims one push, not zero', () {
        expect(
          engine.resolveCoachCommandNotificationLimit(
            recentSuccessCount: 5,
            recentFailureCount: 0,
            riskScore: 50,
          ),
          2,
        );
      });

      test(
        'the limit never drops below 1 once the suppression gate is clear',
        () {
          expect(
            engine.resolveCoachCommandNotificationLimit(
              recentSuccessCount: 10,
              recentFailureCount: 0,
              riskScore: 50,
            ),
            greaterThanOrEqualTo(1),
          );
        },
      );
    });

    group('calculatePercentTrend', () {
      final engine = BehaviorEngine();

      test('fewer than 2 values reports N/A', () {
        expect(engine.calculatePercentTrend(const []), 'N/A');
        expect(engine.calculatePercentTrend(const [5]), 'N/A');
      });

      test('an even split reports the percent change between halves', () {
        // firstHalf = [10, 10] avg 10, secondHalf = [15, 15] avg 15 ->
        // (15-10)/10*100 = 50.0
        expect(engine.calculatePercentTrend(const [10, 10, 15, 15]), '50.0');
      });

      test('an odd count gives the extra value to the first half', () {
        // values.length=5, ceil(5/2)=3 -> firstHalf=[a,b,c], secondHalf=[d,e]
        // firstHalf = [10,10,10] avg 10, secondHalf = [20,20] avg 20 ->
        // (20-10)/10*100 = 100.0
        expect(
          engine.calculatePercentTrend(const [10, 10, 10, 20, 20]),
          '100.0',
        );
      });

      test('a decline reports a negative percentage', () {
        expect(engine.calculatePercentTrend(const [20, 20, 10, 10]), '-50.0');
      });

      test('a first-half average of zero would previously divide by zero and '
          'show Infinity/NaN — now reports N/A when the second half moved', () {
        expect(engine.calculatePercentTrend(const [0, 0, 10, 10]), 'N/A');
      });

      test('both halves at zero reports 0.0 rather than NaN', () {
        expect(engine.calculatePercentTrend(const [0, 0, 0, 0]), '0.0');
      });
    });

    group('calculateImprovementLabel', () {
      final engine = BehaviorEngine();

      test('more than 0.2 above the baseline is improving', () {
        expect(engine.calculateImprovementLabel(5.3, 5.0), 'trendImproving');
      });

      test('more than 0.2 below the baseline is declining', () {
        expect(engine.calculateImprovementLabel(4.7, 5.0), 'trendDeclining');
      });

      test('within the 0.2 dead zone on either side is stable', () {
        expect(engine.calculateImprovementLabel(5.2, 5.0), 'trendStable');
        expect(engine.calculateImprovementLabel(4.8, 5.0), 'trendStable');
        expect(engine.calculateImprovementLabel(5.0, 5.0), 'trendStable');
      });

      test('exactly at the 0.2 boundary is still stable, not improving', () {
        // The comparison is strictly-greater-than, so landing exactly on
        // baseline + 0.2 must not tip into "improving".
        expect(engine.calculateImprovementLabel(5.2, 5.0), 'trendStable');
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

    group('generateProgressiveCadenceTask180', () {
      final engine = BehaviorEngine();

      // Regression coverage: this used to escalate to open-ended multi-day
      // full-abstinence goals ("1-week smoke-free goal: complete all tasks
      // for 7 days") purely from elapsed calendar days since the user's
      // first survey — the exact "time since join date" anti-pattern this
      // app's architecture rejects everywhere else, since the product is
      // gradual reduction and the user keeps smoking throughout it. It also
      // bypassed the duration-barrier consent switch: StorageService
      // .buildAdaptiveNoSmokePlan correctly returns no items when a user has
      // turned duration-barrier tasks off, but this function's output still
      // lands in todaysTasks as home_page.dart's fallback, so it could
      // become someone's only assigned task despite opting out of exactly
      // this kind of escalating commitment. Now capped at the same
      // bounded-minute-interval ceiling _hardTasks already uses.
      AdaptivePlan planAtDay(int day) => AdaptivePlan(
        generatedAt: DateTime(2026, 1, 1),
        targetDays: 180,
        currentWeek: (day / 7).ceil(),
        currentDay: day,
        daysRemaining: 180 - day,
        weeklyRiskTarget: 40,
        difficulty: 'medium',
        cadenceLevel: 'one_day',
        focusAreas: const [],
      );

      test(
        'never returns a multi-day full-abstinence goal at any elapsed day, with or without evidence',
        () {
          const bannedMultiDayGoals = [
            '2 gun sigarasiz kalma plani: kriz aninda 10 derin nefes + su uygulayin.',
            '1 hafta sigarasiz kalma hedefi: 7 gun boyunca tum gorevleri tamamlayin.',
            '1 gun sigarasiz kalma gorevi: ilk sigarayi en az 90 dakika erteleyin.',
            '2 gun sigarasiz kalma gorevi: 48 saat boyunca tetikleyicilerde sigarayi erteleyin.',
          ];
          for (final day in [1, 60, 90, 120, 179]) {
            for (final evidence in [
              (success: 0, failure: 0),
              (success: 5, failure: 0),
              (success: 0, failure: 5),
              (success: 3, failure: 3),
            ]) {
              final task = engine.generateProgressiveCadenceTask180(
                plan: planAtDay(day),
                recentSuccessCount: evidence.success,
                recentFailureCount: evidence.failure,
              );
              expect(
                bannedMultiDayGoals.contains(task),
                isFalse,
                reason:
                    'day $day, evidence $evidence produced a banned '
                    'multi-day goal: "$task"',
              );
            }
          }
        },
      );

      test(
        'day 120+ with real success evidence and no struggle escalates to the 120-minute bounded task',
        () {
          expect(
            engine.generateProgressiveCadenceTask180(
              plan: planAtDay(150),
              recentSuccessCount: 4,
              recentFailureCount: 1,
            ),
            '120 dakika sigarasiz kal',
          );
        },
      );

      test(
        'day 60-119 with real success evidence and no struggle escalates to the 90-minute bounded task',
        () {
          expect(
            engine.generateProgressiveCadenceTask180(
              plan: planAtDay(70),
              recentSuccessCount: 3,
              recentFailureCount: 0,
            ),
            '90 dakika sigarasiz kal',
          );
        },
      );

      test(
        'day 120+ with zero logged success never escalates, regardless of elapsed time',
        () {
          expect(
            engine.generateProgressiveCadenceTask180(
              plan: planAtDay(179),
              recentSuccessCount: 0,
              recentFailureCount: 0,
            ),
            '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.',
          );
        },
      );

      test(
        'struggling (more recent failures than successes) always steps down to the easiest task',
        () {
          expect(
            engine.generateProgressiveCadenceTask180(
              plan: planAtDay(150),
              recentSuccessCount: 1,
              recentFailureCount: 3,
            ),
            'Ilk sigarayi 10 dakika ertele',
          );
        },
      );

      test(
        'a fresh user (no evidence, early day) gets the same-day craving-delay task',
        () {
          expect(
            engine.generateProgressiveCadenceTask180(
              plan: planAtDay(1),
              recentSuccessCount: 0,
              recentFailureCount: 0,
            ),
            '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.',
          );
        },
      );
    });
  });
}
