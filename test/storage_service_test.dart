import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/breath_progress_record.dart';
import 'package:no_smoke/models/cough_test_record.dart';
import 'package:no_smoke/models/smoking_event.dart';
import 'package:no_smoke/models/snoring_probe_event.dart';
import 'package:no_smoke/models/step_counter_sample.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/services/smoking_interval_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_test').path;
  }
}

/// Unlike [_FakePathProviderPlatform], returns the same directory every
/// call — needed for the migration test, which has to write a legacy
/// database file and then have [StorageService] reopen that exact path.
class _FixedPathProviderPlatform extends PathProviderPlatform {
  _FixedPathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    final storage = StorageService();
    await storage.clearAllData();
  });

  test('saves and loads survey history from the local database', () async {
    final storage = StorageService();
    final record = SurveyRecord(
      id: '1',
      completedAt: DateTime(2024, 1, 1),
      type: 'initial',
      title: 'Başlangıç Anketi',
      name: 'Ada',
      packsPerDay: '1 paket',
      exhaleTestSeconds: 6,
      inhaleTestSeconds: 8,
      riskScore: 40,
      riskLevel: 'ORTA',
      consecutiveSmokingHabit: 'Evet, bazen',
      consecutiveSmokingCount: '4 adet',
    );

    await storage.saveSurveyRecord(record);
    final history = await storage.loadSurveyHistory();

    expect(history, hasLength(1));
    expect(history.first.name, 'Ada');
    expect(history.first.riskLevel, 'ORTA');
    expect(history.first.consecutiveSmokingHabit, 'Evet, bazen');
    expect(history.first.consecutiveSmokingCount, '4 adet');
  });

  group('clearAllData (regression coverage)', () {
    // A user resetting their data (Settings -> Reset Data), deleting their
    // account, or switching Google accounts all funnel through this one
    // function. subscription_state used to be wiped along with everything
    // else, which meant any of those three flows could grant a fresh
    // 14-day trial for free, indefinitely — startTrialIfNeeded only checks
    // whether *a* trial row exists, not whether one was ever spent.
    test('the subscription/trial row survives a data reset', () async {
      final storage = StorageService();
      final trialStart = DateTime(2024, 1, 1);
      await storage.saveSubscriptionState(
        SubscriptionState(
          trialStartedAt: trialStart,
          status: SubscriptionStatus.trial,
          updatedAt: trialStart,
        ),
      );

      await storage.clearAllData();

      final state = await storage.loadSubscriptionState();
      expect(state, isNotNull);
      expect(state!.trialStartedAt, trialStart);
      expect(state.status, SubscriptionStatus.trial);
    });

    test(
      'startTrialIfNeeded does not restart an already-spent trial after a reset',
      () async {
        final storage = StorageService();
        final trialStart = DateTime(2024, 1, 1);
        await storage.saveSubscriptionState(
          SubscriptionState(
            trialStartedAt: trialStart,
            status: SubscriptionStatus.expired,
            updatedAt: trialStart,
          ),
        );

        await storage.clearAllData();
        await storage.startTrialIfNeeded();

        final state = await storage.loadSubscriptionState();
        // Still the original trial start, not today — clearAllData must not
        // have erased it, so startTrialIfNeeded sees an existing
        // trialStartedAt and declines to grant a new one.
        expect(state!.trialStartedAt, trialStart);
      },
    );

    test('everything else is still actually cleared', () async {
      final storage = StorageService();
      await storage.saveSurveyRecord(
        SurveyRecord(
          id: 'reset_check',
          completedAt: DateTime(2024, 1, 1),
          type: 'initial',
          title: 'Başlangıç Anketi',
          name: 'Ada',
          packsPerDay: '1 paket',
          exhaleTestSeconds: 6,
          inhaleTestSeconds: 8,
          riskScore: 40,
          riskLevel: 'ORTA',
          consecutiveSmokingHabit: 'Evet, bazen',
          consecutiveSmokingCount: '4 adet',
        ),
      );
      await storage.saveSetting('some_setting', 'some_value');

      await storage.clearAllData();

      expect(await storage.loadSurveyHistory(), isEmpty);
      expect(await storage.loadSetting('some_setting'), isNull);
    });
  });

  group(
    'recordNotificationSent / loadNotificationBudgetState (regression coverage)',
    () {
      // A task alert (or any owed notification) can be scheduled hours
      // ahead and its fire time can land on the next calendar day even
      // though the code scheduling it is running today. recordAt used to
      // key the daily-budget ledger off that (possibly tomorrow) fire
      // time instead of the real moment the call happens, so scheduling
      // a late-evening task could silently reset the whole day's ledger
      // for anything checked afterward — losing both the offered-count
      // cap and the spacing lastSentAt.
      test(
        'a fire time on the next calendar day is still recorded under today, not tomorrow',
        () async {
          final storage = StorageService();
          final today = DateTime(2026, 1, 1, 22, 0);
          final tomorrowFireTime = DateTime(2026, 1, 2, 1, 0);

          await storage.recordNotificationSent(
            countsAgainstBudget: false,
            at: tomorrowFireTime,
            now: today,
          );

          final (todayCount, todayLastSent) = await storage
              .loadNotificationBudgetState(now: today);
          expect(todayLastSent, isNotNull);

          final (tomorrowCount, tomorrowLastSent) = await storage
              .loadNotificationBudgetState(now: tomorrowFireTime);
          // The real next day has not arrived yet — looking the ledger up
          // under it must not find anything, and must not have silently
          // consumed today's ledger either.
          expect(tomorrowLastSent, isNull);
          expect(tomorrowCount, 0);
          expect(todayCount, 0); // owed kind, never spends the allowance
        },
      );

      test(
        'a later same-day call accumulates against the ledger instead of resetting it',
        () async {
          final storage = StorageService();
          final today = DateTime(2026, 1, 1, 9, 0);
          final tonightFireTime = DateTime(2026, 1, 1, 23, 30);
          final laterToday = DateTime(2026, 1, 1, 10, 0);

          // An owed notification scheduled this morning for tonight...
          await storage.recordNotificationSent(
            countsAgainstBudget: false,
            at: tonightFireTime,
            now: today,
          );
          // ...must not make an offered notification checked an hour
          // later today see a reset (0, null) ledger.
          await storage.recordNotificationSent(
            countsAgainstBudget: true,
            now: laterToday,
          );

          final (count, lastSent) = await storage.loadNotificationBudgetState(
            now: laterToday,
          );
          expect(count, 1);
          expect(lastSent, isNotNull);
        },
      );
    },
  );

  group('loadLastSmokingEventTimestamp (regression coverage)', () {
    test('returns null when nothing has ever been logged', () async {
      final storage = StorageService();
      expect(await storage.loadLastSmokingEventTimestamp(), isNull);
    });

    test(
      'returns the most recent event, not the first or an arbitrary one',
      () async {
        final storage = StorageService();
        final now = DateTime.now();
        await storage.saveSmokingEvent(
          SmokingEvent(
            id: 'older',
            timestamp: now.subtract(const Duration(hours: 5)),
            source: 'quick_log',
            approximate: false,
          ),
        );
        final newest = now.subtract(const Duration(minutes: 10));
        await storage.saveSmokingEvent(
          SmokingEvent(
            id: 'newest',
            timestamp: newest,
            source: 'quick_log',
            approximate: false,
          ),
        );
        await storage.saveSmokingEvent(
          SmokingEvent(
            id: 'middle',
            timestamp: now.subtract(const Duration(hours: 2)),
            source: 'quick_log',
            approximate: false,
          ),
        );

        final result = await storage.loadLastSmokingEventTimestamp();
        expect(result, newest);
      },
    );
  });

  test('saves task results in the local database', () async {
    final storage = StorageService();

    await storage.saveTaskResult(
      taskTitle: 'Meditasyon',
      taskResult: 'Tamamlandı',
      completedAt: DateTime(2024, 2, 2),
    );

    final history = await storage.loadSurveyHistory();

    expect(history, hasLength(1));
    expect(history.first.type, 'task_result');
    expect(history.first.taskTitle, 'Meditasyon');
    expect(history.first.taskResult, 'Tamamlandı');
  });

  group('loadTaskHistory / loadTaskOutcomeSummary (regression coverage)', () {
    // Regression coverage for a bug where task acceptance sank completion
    // rates toward 50%: every accepted task writes a 'started' row (see
    // NotificationService's ACTION_TASK_DONE handler) in addition to
    // whatever outcome eventually follows, and 'started' used to fall into
    // loadTaskHistory's failure bucket by default (it matches none of the
    // success substrings) even for a user who never actually failed a task.
    test(
      'a "started" row alone is excluded, not counted as a failure',
      () async {
        final storage = StorageService();
        await storage.saveTaskResult(
          taskTitle: 'ADAPTIVE_NO_SMOKE:15',
          taskResult: 'started',
          completedAt: DateTime(2024, 3, 1),
        );

        final history = await storage.loadTaskHistory();
        expect(history, isEmpty);

        final summary = await storage.loadTaskOutcomeSummary();
        expect(summary['successCount'], 0);
        expect(summary['failureCount'], 0);
      },
    );

    test(
      'a full started -> willpower_success pair counts as exactly one success',
      () async {
        final storage = StorageService();
        await storage.saveTaskResult(
          taskTitle: 'ADAPTIVE_NO_SMOKE:15',
          taskResult: 'started',
          completedAt: DateTime(2024, 3, 1, 9, 0),
        );
        await storage.saveTaskResult(
          taskTitle: 'ADAPTIVE_NO_SMOKE:15',
          taskResult: 'willpower_success',
          completedAt: DateTime(2024, 3, 1, 9, 30),
        );

        final history = await storage.loadTaskHistory();
        expect(history, hasLength(1));
        expect(history.single.completed, isTrue);

        final summary = await storage.loadTaskOutcomeSummary();
        expect(summary['successCount'], 1);
        expect(summary['failureCount'], 0);
      },
    );

    test('a value containing "basarisiz" is a failure, not a success '
        '("basarisiz" contains "basar" as a prefix)', () async {
      final storage = StorageService();
      await storage.saveTaskResult(
        taskTitle: 'ADAPTIVE_NO_SMOKE:15',
        taskResult: 'gorev_basarisiz',
        completedAt: DateTime(2024, 3, 1),
      );

      final history = await storage.loadTaskHistory();
      expect(history, hasLength(1));
      expect(history.single.completed, isFalse);
    });

    test('a real failure outcome is still counted as a failure', () async {
      final storage = StorageService();
      await storage.saveTaskResult(
        taskTitle: 'ADAPTIVE_NO_SMOKE:15',
        taskResult: 'started',
        completedAt: DateTime(2024, 3, 1, 9, 0),
      );
      await storage.saveTaskResult(
        taskTitle: 'ADAPTIVE_NO_SMOKE:15',
        taskResult: 'failed_missed',
        completedAt: DateTime(2024, 3, 1, 9, 30),
      );

      final history = await storage.loadTaskHistory();
      // 'started' is excluded, 'failed_missed' matches none of the success
      // substrings so it's counted as a failure — exactly one outcome row.
      expect(history, hasLength(1));
      expect(history.single.completed, isFalse);

      final summary = await storage.loadTaskOutcomeSummary();
      expect(summary['successCount'], 0);
      expect(summary['failureCount'], 1);
    });
  });

  test('calculates breath averages from history', () async {
    final storage = StorageService();
    final now = DateTime.now();
    await storage.saveSurveyRecord(
      SurveyRecord(
        id: '3',
        completedAt: DateTime(now.year, now.month, now.day),
        type: 'breath_test',
        title: 'Nefes Testi',
        name: 'Ada',
        packsPerDay: '1 paket',
        exhaleTestSeconds: 5,
        inhaleTestSeconds: 6,
        riskScore: 40,
        riskLevel: 'ORTA',
      ),
    );
    await storage.saveSurveyRecord(
      SurveyRecord(
        id: '4',
        completedAt: DateTime(now.year, now.month, now.day, 12),
        type: 'breath_test',
        title: 'Nefes Testi',
        name: 'Ada',
        packsPerDay: '1 paket',
        exhaleTestSeconds: 7,
        inhaleTestSeconds: 8,
        riskScore: 40,
        riskLevel: 'ORTA',
      ),
    );

    final metrics = await storage.loadBreathMetrics();

    expect(metrics['dailyAverage'], 6.5);
    expect(metrics['weeklyAverage'], 6.5);
    expect(metrics['monthlyAverage'], 6.5);
  });

  test(
    'persists isProfileCompleted through registration completion flag',
    () async {
      final storage = StorageService();

      expect(await storage.loadIsProfileCompleted(), isFalse);

      await storage.saveInitialRegistrationCompleted(true);

      expect(await storage.loadIsProfileCompleted(), isTrue);
      expect(await storage.loadInitialRegistrationCompleted(), isTrue);
    },
  );

  // --- Haftalık kadans iş kuralları ---

  test('isWeeklySurveyOverdue: anket yoksa false döner', () async {
    final storage = StorageService();
    expect(await storage.isWeeklySurveyOverdue(), isFalse);
  });

  test('isWeeklySurveyOverdue: 6 gün geçmişse false döner', () async {
    final storage = StorageService();
    final sixDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    await storage.saveSurveyRecord(
      SurveyRecord(
        id: 'w1',
        completedAt: sixDaysAgo,
        type: 'initial',
        title: 'Başlangıç',
        name: 'Test',
        packsPerDay: '1',
        exhaleTestSeconds: 5,
        inhaleTestSeconds: 5,
        riskScore: 30,
        riskLevel: 'DÜŞÜK',
      ),
    );
    expect(await storage.isWeeklySurveyOverdue(), isFalse);
  });

  test('isWeeklySurveyOverdue: 8 gün geçmişse true döner', () async {
    final storage = StorageService();
    final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
    await storage.saveSurveyRecord(
      SurveyRecord(
        id: 'w2',
        completedAt: eightDaysAgo,
        type: 'weekly',
        title: 'Haftalık',
        name: 'Test',
        packsPerDay: '1',
        exhaleTestSeconds: 5,
        inhaleTestSeconds: 5,
        riskScore: 35,
        riskLevel: 'ORTA',
      ),
    );
    expect(await storage.isWeeklySurveyOverdue(), isTrue);
  });

  test('loadWeeklySurveyDueDate: son anketten 7 gün sonrasını döner', () async {
    final storage = StorageService();
    final surveyDate = DateTime(2025, 3, 1);
    await storage.saveSurveyRecord(
      SurveyRecord(
        id: 'w3',
        completedAt: surveyDate,
        type: 'initial',
        title: 'Başlangıç',
        name: 'Test',
        packsPerDay: '1',
        exhaleTestSeconds: 5,
        inhaleTestSeconds: 5,
        riskScore: 30,
        riskLevel: 'DÜŞÜK',
      ),
    );
    final dueDate = await storage.loadWeeklySurveyDueDate();
    expect(dueDate, equals(DateTime(2025, 3, 8)));
  });

  test('hasWeeklySurveyBeenPromptedToday: başlangıçta false', () async {
    final storage = StorageService();
    expect(await storage.hasWeeklySurveyBeenPromptedToday(), isFalse);
  });

  test(
    'markWeeklySurveyPromptedToday: işaretlendikten sonra true döner',
    () async {
      final storage = StorageService();
      await storage.markWeeklySurveyPromptedToday();
      expect(await storage.hasWeeklySurveyBeenPromptedToday(), isTrue);
    },
  );

  test(
    'markWeeklySurveyPromptedToday: geçmiş tarihten sonra false döner',
    () async {
      final storage = StorageService();
      // Dün için kayıt
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await storage.saveSetting(
        'last_weekly_survey_prompt_at',
        yesterday.toIso8601String(),
      );
      expect(await storage.hasWeeklySurveyBeenPromptedToday(), isFalse);
    },
  );

  test(
    'loadLatestConsentDecision: hiç karar verilmemişse null döner',
    () async {
      final storage = StorageService();
      expect(
        await storage.loadLatestConsentDecision('sleep_intelligence'),
        isNull,
      );
    },
  );

  test('recordConsentDecision: kaydedilen kararı doğru döner', () async {
    final storage = StorageService();
    await storage.recordConsentDecision(
      featureKey: 'sleep_intelligence',
      granted: true,
      consentTextVersion: 'v1',
    );
    final decision = await storage.loadLatestConsentDecision(
      'sleep_intelligence',
    );
    expect(decision, isNotNull);
    expect(decision!['granted'], isTrue);
    expect(decision['consentTextVersion'], 'v1');
    expect(decision['createdAt'], isA<DateTime>());
  });

  test(
    'recordConsentDecision: en son karar (geri çekme dahil) döner',
    () async {
      final storage = StorageService();
      await storage.recordConsentDecision(
        featureKey: 'location_intelligence',
        granted: true,
        consentTextVersion: 'v1',
      );
      await storage.recordConsentDecision(
        featureKey: 'location_intelligence',
        granted: false,
        consentTextVersion: 'v1',
      );
      final decision = await storage.loadLatestConsentDecision(
        'location_intelligence',
      );
      expect(decision!['granted'], isFalse);
    },
  );

  test(
    'recordConsentDecision: farklı özellikler birbirini etkilemez',
    () async {
      final storage = StorageService();
      await storage.recordConsentDecision(
        featureKey: 'wearable_intelligence',
        granted: true,
        consentTextVersion: 'v1',
      );
      expect(
        await storage.loadLatestConsentDecision('sleep_intelligence'),
        isNull,
      );
    },
  );

  test('isRecentlySedentary: yeterli örnek yoksa false döner', () async {
    final storage = StorageService();
    expect(await storage.isRecentlySedentary(), isFalse);
  });

  test(
    'isRecentlySedentary: uzun aralıkta çok az adım varsa true döner',
    () async {
      final storage = StorageService();
      final now = DateTime.now();
      await storage.saveStepCounterSample(
        StepCounterSample(
          id: 'a',
          createdAt: now.subtract(const Duration(hours: 2)),
          cumulativeSteps: 1000,
        ),
      );
      await storage.saveStepCounterSample(
        StepCounterSample(id: 'b', createdAt: now, cumulativeSteps: 1050),
      );
      expect(await storage.isRecentlySedentary(), isTrue);
    },
  );

  test('isRecentlySedentary: gerçek adım artışında false döner', () async {
    final storage = StorageService();
    final now = DateTime.now();
    await storage.saveStepCounterSample(
      StepCounterSample(
        id: 'a',
        createdAt: now.subtract(const Duration(hours: 2)),
        cumulativeSteps: 1000,
      ),
    );
    await storage.saveStepCounterSample(
      StepCounterSample(id: 'b', createdAt: now, cumulativeSteps: 3500),
    );
    expect(await storage.isRecentlySedentary(), isFalse);
  });

  group('buildDailyProgressReport', () {
    test(
      'reports no evidence on a fresh install with nothing logged',
      () async {
        final storage = StorageService();

        final report = await storage.buildDailyProgressReport();

        expect(report.reductionProgress.hasEvidence, isFalse);
        expect(report.todaySmokedCount, 0);
        expect(report.latestCoughTest, isNull);
      },
    );

    test('reflects today\'s logged cigarette count', () async {
      final storage = StorageService();
      // Anchored to noon rather than DateTime.now() — a `now`-relative
      // second timestamp an hour earlier crosses into "yesterday" whenever
      // this test happens to run in the first hour after local midnight,
      // making todaySmokedCount flake between 1 and 2 depending on the
      // clock. Noon has an hour of headroom on both sides.
      final now = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        12,
      );
      await storage.logSmokingNow(timestamp: now);
      await storage.logSmokingNow(
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      final report = await storage.buildDailyProgressReport(now: now);

      expect(report.todaySmokedCount, 2);
    });

    test('carries the latest cough test through', () async {
      final storage = StorageService();
      final now = DateTime.now();
      await storage.saveCoughTestRecord(
        CoughTestRecord(
          id: 'cough_report_1',
          createdAt: now,
          coughCount: 5,
          testDurationSeconds: 30,
          severityScore: 40,
          severityLevel: 'mild',
        ),
      );

      final report = await storage.buildDailyProgressReport(now: now);

      expect(report.latestCoughTest?.coughCount, 5);
    });

    group('hasCoughTestSince (regression coverage)', () {
      // Regression coverage: CoughTestRecord.toJson() writes createdAt as a
      // plain local-time ISO8601 string (no .toUtc()), but hasCoughTestSince
      // used to compare that string in SQL directly against
      // since.toUtc().toIso8601String() — two ISO8601 strings in different
      // zones aren't comparable as if they were the same clock, so the
      // effective threshold silently drifted by the device's own UTC
      // offset (e.g. UTC+3 shifted the boundary 3 hours later than asked).
      test('a test taken 2 hours ago counts as "since 3 hours ago" '
          "regardless of the device's UTC offset", () async {
        final storage = StorageService();
        final now = DateTime.now();
        await storage.saveCoughTestRecord(
          CoughTestRecord(
            id: 'cough_since_1',
            createdAt: now.subtract(const Duration(hours: 2)),
            coughCount: 3,
            testDurationSeconds: 30,
            severityScore: 30,
            severityLevel: 'mild',
          ),
        );

        final hasRecent = await storage.hasCoughTestSince(
          now.subtract(const Duration(hours: 3)),
        );
        expect(hasRecent, isTrue);
      });

      test(
        'a test taken 5 hours ago does not count as "since 3 hours ago"',
        () async {
          final storage = StorageService();
          final now = DateTime.now();
          await storage.saveCoughTestRecord(
            CoughTestRecord(
              id: 'cough_since_2',
              createdAt: now.subtract(const Duration(hours: 5)),
              coughCount: 3,
              testDurationSeconds: 30,
              severityScore: 30,
              severityLevel: 'mild',
            ),
          );

          final hasRecent = await storage.hasCoughTestSince(
            now.subtract(const Duration(hours: 3)),
          );
          expect(hasRecent, isFalse);
        },
      );

      test('false when no cough test has ever been recorded', () async {
        final storage = StorageService();
        final hasAny = await storage.hasCoughTestSince(
          DateTime.now().subtract(const Duration(days: 7)),
        );
        expect(hasAny, isFalse);
      });
    });

    test('task success rate covers the last 7 days, not all time', () async {
      final storage = StorageService();
      final now = DateTime.now();

      // Outside the 7-day window entirely — must not affect the figure.
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: 'ADAPTIVE_NO_SMOKE:30',
        outcome: AdaptiveTaskOutcome.missed,
        plannedDurationMinutes: 30,
        scheduledAt: now.subtract(const Duration(days: 30)),
        respondedAt: now.subtract(const Duration(days: 30)),
      );
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: 'ADAPTIVE_NO_SMOKE:30',
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: 30,
        scheduledAt: now.subtract(const Duration(days: 1)),
        respondedAt: now.subtract(const Duration(days: 1)),
      );

      final report = await storage.buildDailyProgressReport(now: now);

      expect(report.taskSuccessRateLast7Days, 1.0);
    });
  });

  group('snoring probe severity migration', () {
    test('saveManualSnoringProbe/loadSnoringProbeEventsBetween round-trips '
        'severity fields', () async {
      final storage = StorageService();
      final now = DateTime.now();
      await storage.saveManualSnoringProbe(
        SnoringProbeEvent(
          id: 'manualsnoreprobe_1',
          createdAt: now,
          snoreLikely: true,
          severityScore: 72,
          severityLevel: 'severe',
        ),
      );

      final events = await storage.loadSnoringProbeEventsBetween(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
      );

      expect(events, hasLength(1));
      expect(events.single.snoreLikely, isTrue);
      expect(events.single.severityScore, 72);
      expect(events.single.severityLevel, 'severe');
    });

    test('a pre-migration row with no severity columns loads as null '
        'instead of crashing', () async {
      final storage = StorageService();
      final db = await storage.database;
      final now = DateTime.now();
      // Simulates a row written by an older APK version, before the
      // severityScore/severityLevel columns existed — insert without them
      // to confirm the migration's ALTER TABLE left them nullable and the
      // read path tolerates missing values on old rows.
      await db.insert('snoring_probe_events', {
        'id': 'snoreprobe_legacy',
        'createdAt': now.toUtc().toIso8601String(),
        'snoreLikely': 1,
      });

      final events = await storage.loadSnoringProbeEventsBetween(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
      );

      expect(events, hasLength(1));
      expect(events.single.snoreLikely, isTrue);
      expect(events.single.severityScore, isNull);
      expect(events.single.severityLevel, isNull);
    });
  });

  group('snoring probe captureSucceeded (Faz 2 -- Android 11+ mic fix)', () {
    test(
      'saveManualSnoringProbe always records captureSucceeded true',
      () async {
        final storage = StorageService();
        final now = DateTime.now();
        await storage.saveManualSnoringProbe(
          SnoringProbeEvent(
            id: 'manualsnoreprobe_2',
            createdAt: now,
            snoreLikely: false,
          ),
        );

        final events = await storage.loadSnoringProbeEventsBetween(
          start: now.subtract(const Duration(minutes: 1)),
          end: now.add(const Duration(minutes: 1)),
        );

        expect(events.single.captureSucceeded, isTrue);
      },
    );

    test('a pre-migration row with no captureSucceeded column loads as null '
        'instead of crashing', () async {
      final storage = StorageService();
      final db = await storage.database;
      final now = DateTime.now();
      await db.insert('snoring_probe_events', {
        'id': 'snoreprobe_legacy_2',
        'createdAt': now.toUtc().toIso8601String(),
        'snoreLikely': 0,
      });

      final events = await storage.loadSnoringProbeEventsBetween(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
      );

      expect(events.single.captureSucceeded, isNull);
    });

    test(
      'countRecentSnoreLikelyEvents excludes rows where the capture itself '
      'failed, even if snoreLikely happens to be set on them -- a night the '
      'microphone never opened must not silently count as a clean night',
      () async {
        final storage = StorageService();
        final db = await storage.database;
        final now = DateTime.now();

        // A real snore-likely reading from a successful capture.
        await db.insert('snoring_probe_events', {
          'id': 'snoreprobe_ok',
          'createdAt': now.toUtc().toIso8601String(),
          'snoreLikely': 1,
          'captureSucceeded': 1,
          'source': SnoringProbeEvent.sourceOvernight,
        });
        // A failed capture that (as SnoringCaptureService.kt writes it)
        // defaults snoreLikely to false -- must still be excluded from the
        // count explicitly, not just incidentally.
        await db.insert('snoring_probe_events', {
          'id': 'snoreprobe_failed',
          'createdAt': now.toUtc().toIso8601String(),
          'snoreLikely': 0,
          'captureSucceeded': 0,
          'source': SnoringProbeEvent.sourceOvernight,
        });

        final count = await storage.countRecentSnoreLikelyEvents(
          since: now.subtract(const Duration(minutes: 5)),
        );

        expect(count, 1);
      },
    );
  });

  group('snoring probe source (Faz 3 -- daytime test must not pollute the '
      'nightly summary/risk score)', () {
    test(
      'a manual (daytime) snore-likely probe is excluded from '
      'countRecentSnoreLikelyEvents even though it happened in the window',
      () async {
        final storage = StorageService();
        final now = DateTime.now();

        // One real overnight probe, snore-likely -- source written
        // explicitly, same as SnoringProbeStore.insertProbe does natively.
        final db = await storage.database;
        await db.insert('snoring_probe_events', {
          'id': 'snoreprobe_overnight_1',
          'createdAt': now.toUtc().toIso8601String(),
          'snoreLikely': 1,
          'captureSucceeded': 1,
          'source': SnoringProbeEvent.sourceOvernight,
        });

        // The user got curious and ran the manual daytime test twice, both
        // snore-likely -- these must never inflate "last night's" count.
        await storage.saveManualSnoringProbe(
          SnoringProbeEvent(
            id: 'manualsnoreprobe_1',
            createdAt: now,
            snoreLikely: true,
            severityScore: 80,
            severityLevel: 'severe',
          ),
        );
        await storage.saveManualSnoringProbe(
          SnoringProbeEvent(
            id: 'manualsnoreprobe_2',
            createdAt: now,
            snoreLikely: true,
            severityScore: 60,
            severityLevel: 'moderate',
          ),
        );

        final count = await storage.countRecentSnoreLikelyEvents(
          since: now.subtract(const Duration(minutes: 5)),
        );

        // Only the one overnight row counts, not the two manual ones.
        expect(count, 1);
      },
    );

    test('id-prefix backfill classifies pre-existing rows correctly: '
        "'snoreprobe_' as overnight, 'manualsnoreprobe_' as manual", () async {
      // Simulates a device already on a schema version before the source
      // column existed on snoring_probe_events: create the table by hand,
      // without the column, then run it through the real onUpgrade path
      // by opening it with StorageService -- same pattern as the
      // breath_progress_records schemaVersion migration test above.
      final dir = Directory.systemTemp.createTempSync(
        'no_smoke_snoring_source_migration',
      );
      PathProviderPlatform.instance = _FixedPathProviderPlatform(dir.path);
      final dbPath = '${dir.path}/no_smoke.db';
      final now = DateTime.now();

      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          // Below the real code's current version (32) so that opening it
          // with StorageService below actually goes through onUpgrade
          // instead of finding a matching version and skipping every
          // callback.
          version: 31,
          onCreate: (db, version) async {
            await db.execute('''
                CREATE TABLE snoring_probe_events (
                  id TEXT PRIMARY KEY,
                  createdAt TEXT NOT NULL,
                  snoreLikely INTEGER NOT NULL
                )
              ''');
            await db.insert('snoring_probe_events', {
              'id': 'snoreprobe_legacy_overnight',
              'createdAt': now.toUtc().toIso8601String(),
              'snoreLikely': 1,
            });
            await db.insert('snoring_probe_events', {
              'id': 'manualsnoreprobe_legacy_manual',
              'createdAt': now.toUtc().toIso8601String(),
              'snoreLikely': 1,
            });
          },
        ),
      );
      await legacyDb.close();

      final storage = StorageService();
      await storage.closeDatabaseConnection();

      final overnightOnly = await storage.loadSnoringProbeEventsBetween(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
        source: SnoringProbeEvent.sourceOvernight,
      );
      final manualOnly = await storage.loadSnoringProbeEventsBetween(
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
        source: SnoringProbeEvent.sourceManual,
      );

      expect(
        overnightOnly.map((e) => e.id),
        contains('snoreprobe_legacy_overnight'),
      );
      expect(
        manualOnly.map((e) => e.id),
        contains('manualsnoreprobe_legacy_manual'),
      );

      await storage.closeDatabaseConnection();
      PathProviderPlatform.instance = _FakePathProviderPlatform();
    });
  });

  group('subscription state', () {
    test('startTrialIfNeeded sets trialStartedAt and status=trial on first '
        'call', () async {
      final storage = StorageService();

      await storage.startTrialIfNeeded();

      final state = await storage.loadSubscriptionState();
      expect(state, isNotNull);
      expect(state!.trialStartedAt, isNotNull);
      expect(state.status, SubscriptionStatus.trial);
    });

    test(
      'startTrialIfNeeded is a no-op once trialStartedAt is already set',
      () async {
        final storage = StorageService();

        await storage.startTrialIfNeeded();
        final first = await storage.loadTrialStartedAt();

        await Future.delayed(const Duration(milliseconds: 5));
        await storage.startTrialIfNeeded();
        final second = await storage.loadTrialStartedAt();

        expect(second, first);
      },
    );

    test('saveSubscriptionState upserts the single current row', () async {
      final storage = StorageService();
      final now = DateTime.now();

      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.active,
          productId: 'monthly_sub',
          purchaseToken: 'token_1',
          updatedAt: now,
        ),
      );
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.expired,
          productId: 'monthly_sub',
          purchaseToken: 'token_1',
          updatedAt: now.add(const Duration(days: 1)),
        ),
      );

      final state = await storage.loadSubscriptionState();
      expect(state, isNotNull);
      expect(state!.status, SubscriptionStatus.expired);

      final db = await storage.database;
      final rows = await db.query('subscription_state');
      expect(rows, hasLength(1));
    });

    test(
      'loadSubscriptionState returns null when nothing was ever saved',
      () async {
        final storage = StorageService();
        final state = await storage.loadSubscriptionState();
        expect(state, isNull);
      },
    );
  });

  group('duration barrier outcomes reach the learning engine', () {
    test('ADAPTIVE_NO_SMOKE:<minutes> success/smoked rows make '
        'barrierSuccessRate differ from the 0.5 no-data default', () async {
      final storage = StorageService();

      // Two successes, one smoked failure -- a 2/3 rate, nowhere near 0.5,
      // so a bug that quietly falls back to the no-data default would be
      // caught by this assertion instead of accidentally matching.
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: 'ADAPTIVE_NO_SMOKE:45',
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: 45,
        scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
        respondedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: 'ADAPTIVE_NO_SMOKE:50',
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: 50,
        scheduledAt: DateTime.now().subtract(const Duration(hours: 2)),
        respondedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: 'ADAPTIVE_NO_SMOKE:40',
        outcome: AdaptiveTaskOutcome.smoked,
        plannedDurationMinutes: 40,
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        respondedAt: DateTime.now(),
      );

      final dashboard = await storage.loadBehaviorDashboard();
      final barrierLine = dashboard.riskExplanation.firstWhere(
        (line) => line.startsWith('Sure bariyeri uyumu'),
        orElse: () => '',
      );

      expect(
        barrierLine,
        isNot(contains('%50')),
        reason:
            'barrierSuccessRate should reflect the 2/3 real outcomes '
            'above, not the 0.5 fallback that fires when no rows match.',
      );
      expect(barrierLine, contains('%67'));
      expect(barrierLine, contains('son: 2 basarili / 1 basarisiz'));
    });

    test(
      'a legacy SURE-BARIYERI-titled row still counts toward the rate',
      () async {
        final storage = StorageService();

        await storage.saveTaskResult(
          taskTitle: 'SURE-BARIYERI',
          taskResult: 'barrier_success',
          completedAt: DateTime.now(),
        );

        final dashboard = await storage.loadBehaviorDashboard();
        final barrierLine = dashboard.riskExplanation.firstWhere(
          (line) => line.startsWith('Sure bariyeri uyumu'),
          orElse: () => '',
        );

        expect(barrierLine, contains('%100'));
        expect(barrierLine, contains('son: 1 basarili / 0 basarisiz'));
      },
    );
  });

  group('duration barrier consent switch (regression coverage)', () {
    test('duration_barrier_enabled = 0 produces an empty plan', () async {
      final storage = StorageService();
      await storage.saveSetting('duration_barrier_enabled', '0');

      final plan = await storage.buildAdaptiveNoSmokePlan(
        now: DateTime(2026, 1, 1, 10),
        sleepAt: DateTime(2026, 1, 1, 23),
        riskyHours: const [],
      );

      expect(plan.targetTaskCount, 0);
      expect(plan.items, isEmpty);
    });

    test("duration_barrier_preference = 'off' produces an empty plan even "
        "when duration_barrier_enabled is left unset", () async {
      final storage = StorageService();
      await storage.saveSetting('duration_barrier_preference', 'off');

      final plan = await storage.buildAdaptiveNoSmokePlan(
        now: DateTime(2026, 1, 1, 10),
        sleepAt: DateTime(2026, 1, 1, 23),
        riskyHours: const [],
      );

      expect(plan.targetTaskCount, 0);
      expect(plan.items, isEmpty);
    });

    test(
      'frequency az/cok change task COUNT but never the barrier DURATION',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Same wake/sleep window and survey data for all three runs, so any
        // difference in the resulting plan can only come from the frequency
        // setting itself.
        //
        // dailyTaskCount() has its own +/-1 jitter (see
        // smoking_interval_service.dart), so a single run can land two
        // adjacent frequency settings on the same clamped count purely by
        // chance -- this repeats the comparison across several fresh plans
        // (clearAllData between each, since buildAdaptiveNoSmokePlan caches
        // one plan per calendar day) and asserts the *direction* never
        // reverses, rather than asserting one exact count difference that
        // the jitter could occasionally erase.
        // Each frequency gets its OWN Random seeded identically, so the
        // +/-1 jitter sequence is the same for az/orta/cok on every attempt.
        // That isolates the frequency effect exactly instead of hoping the
        // noise averages out -- it used to rely on 10 unseeded samples, and
        // because dailyTaskCount clamps at maxDailyTasks (8) the real gap
        // between 'orta' and 'cok' is ~0.67 rather than 1, small enough for
        // the two means to tie and fail the run at random.
        Future<AdaptiveTaskPlan> planWithFrequency(
          String frequency,
          int seed,
        ) async {
          final storage = StorageService(
            smokingIntervalService: SmokingIntervalService(
              random: Random(seed),
            ),
          );
          await storage.clearAllData();
          await storage.saveSetting(
            'duration_barrier_frequency_preference',
            frequency,
          );
          return storage.buildAdaptiveNoSmokePlan(
            now: DateTime(2026, 1, 1, 10),
            sleepAt: DateTime(2026, 1, 1, 23),
            riskyHours: const [],
          );
        }

        // dailyTaskCount()'s own +/-1 jitter is the same size as the
        // frequency adjustment itself, so any single az/orta/cok trio can
        // have the jitter cancel or reverse the frequency effect purely by
        // chance. Comparing means over many samples is what actually
        // isolates the frequency effect from that noise.
        const sampleSize = 25;
        final allBaseDurations = <int>{};
        var azTotal = 0;
        var ortaTotal = 0;
        var cokTotal = 0;

        for (var attempt = 0; attempt < sampleSize; attempt++) {
          final seed = 1000 + attempt;
          final az = await planWithFrequency('az', seed);
          final orta = await planWithFrequency('orta', seed);
          final cok = await planWithFrequency('cok', seed);

          azTotal += az.targetTaskCount;
          ortaTotal += orta.targetTaskCount;
          cokTotal += cok.targetTaskCount;

          // baseDurationMinutes is the week's actual barrier target (from
          // SmokingIntervalService, no jitter) -- this is the field
          // frequency must never move. Individual item.durationMinutes
          // values are deliberately jittered +/-10% for unpredictability
          // (see DisciplineProtocolService's _durationJitter), so comparing
          // those directly would fail for an unrelated, intentional reason.
          allBaseDurations.add(az.baseDurationMinutes);
          allBaseDurations.add(orta.baseDurationMinutes);
          allBaseDurations.add(cok.baseDurationMinutes);
        }

        final azMean = azTotal / sampleSize;
        final ortaMean = ortaTotal / sampleSize;
        final cokMean = cokTotal / sampleSize;

        expect(
          azMean,
          lessThan(ortaMean),
          reason:
              "'az' averaged $azMean tasks over $sampleSize plans vs "
              "'orta' averaging $ortaMean -- frequency is not lowering the "
              'task count',
        );
        expect(
          cokMean,
          greaterThan(ortaMean),
          reason:
              "'cok' averaged $cokMean tasks over $sampleSize plans vs "
              "'orta' averaging $ortaMean -- frequency is not raising the "
              'task count',
        );

        // The duration axis is untouched by frequency -- every plan across
        // every attempt and every frequency setting should carry the same
        // baseDurationMinutes, since that comes from SmokingIntervalService
        // alone (via loadCurrentBarrierMinutes, which does not vary within
        // one calendar day).
        expect(
          allBaseDurations.length,
          lessThanOrEqualTo(1),
          reason:
              'every plan across all frequency settings should share the '
              'same baseDurationMinutes; frequency must not touch it',
        );
      },
    );

    test('every duration_barrier_* saveSetting call site has a matching '
        'loadSetting reader somewhere in lib/', () async {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final saveKeyPattern = RegExp(
        r"saveSetting\(\s*'(duration_barrier_[a-zA-Z_]+)'",
      );
      final loadKeyPattern = RegExp(
        r"loadSetting\(\s*'(duration_barrier_[a-zA-Z_]+)'",
      );

      final savedKeys = <String>{};
      final loadedKeys = <String>{};
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final match in saveKeyPattern.allMatches(content)) {
          savedKeys.add(match.group(1)!);
        }
        for (final match in loadKeyPattern.allMatches(content)) {
          loadedKeys.add(match.group(1)!);
        }
      }

      expect(
        savedKeys,
        isNotEmpty,
        reason:
            'sanity check -- if this is empty the regex/scan itself is '
            'broken, not that there are no duration_barrier_* settings',
      );
      for (final key in savedKeys) {
        expect(
          loadedKeys,
          contains(key),
          reason:
              '$key is written via saveSetting somewhere but never read '
              'back via loadSetting anywhere in lib/ -- a write with no '
              'reader is exactly the class of bug this regression was.',
        );
      }
    });
  });

  group('breath_progress_records schemaVersion migration', () {
    test(
      'a pre-existing row from before schemaVersion existed is backfilled '
      'to 1 (legacy), not crashed on or silently treated as current',
      () async {
        // Simulates a device already on a schema version before
        // schemaVersion existed on breath_progress_records: create the
        // table by hand, without the column, then run it through the real
        // onUpgrade path by opening it with StorageService.
        final dir = Directory.systemTemp.createTempSync(
          'no_smoke_breath_schema_migration',
        );
        PathProviderPlatform.instance = _FixedPathProviderPlatform(dir.path);
        final dbPath = '${dir.path}/no_smoke.db';

        final legacyDb = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 32,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE breath_progress_records (
                  id TEXT PRIMARY KEY,
                  completedAt TEXT NOT NULL,
                  breathScore REAL NOT NULL,
                  blowDurationSeconds REAL NOT NULL,
                  blowStability REAL NOT NULL,
                  blowIntensity REAL NOT NULL,
                  isNoisyEnvironment INTEGER NOT NULL DEFAULT 0
                )
              ''');
              await db.insert('breath_progress_records', {
                'id': 'pre_migration',
                'completedAt': DateTime(2026, 7, 1).toIso8601String(),
                // Pre-fix rows could have hold+rest time folded into this —
                // an implausible value for a real exhale, on purpose, so the
                // test can't accidentally pass because the value looks fine
                // either way.
                'blowDurationSeconds': 42.0,
                'breathScore': 80.0,
                'blowStability': 0.8,
                'blowIntensity': 0.8,
                'isNoisyEnvironment': 0,
              });
            },
          ),
        );
        await legacyDb.close();

        final storage = StorageService();
        await storage.closeDatabaseConnection();
        final loaded = await storage.loadBreathProgressRecords();

        expect(loaded, hasLength(1));
        expect(loaded.first.schemaVersion, 1);
        expect(
          loaded.first.schemaVersion,
          lessThan(BreathProgressRecord.currentSchemaVersion),
        );

        await storage.closeDatabaseConnection();
        PathProviderPlatform.instance = _FakePathProviderPlatform();
      },
    );

    test('a newly saved record always carries currentSchemaVersion', () async {
      final storage = StorageService();
      await storage.saveBreathProgressRecord(
        BreathProgressRecord(
          id: 'fresh',
          completedAt: DateTime(2026, 8, 1),
          breathScore: 70,
          blowDurationSeconds: 5,
          blowStability: 0.7,
          blowIntensity: 0.7,
        ),
      );

      final loaded = await storage.loadBreathProgressRecords();
      final record = loaded.firstWhere((r) => r.id == 'fresh');
      expect(record.schemaVersion, BreathProgressRecord.currentSchemaVersion);
    });

    test(
      'adaptive observation starts with a stable persisted timestamp',
      () async {
        final storage = StorageService();
        final first = await storage.ensureAdaptiveObservationStartedAt(
          now: DateTime(2026, 8, 16, 10),
        );
        final second = await storage.ensureAdaptiveObservationStartedAt(
          now: DateTime(2026, 8, 17, 10),
        );

        expect(first, DateTime(2026, 8, 16, 10));
        expect(second, first);
      },
    );

    test('adaptive planning waits for a full day and the next wake time', () {
      final storage = StorageService();
      final startedAt = DateTime(2026, 8, 16, 10);

      expect(
        storage.isAdaptivePlanningEligible(
          now: DateTime(2026, 8, 17, 9, 59),
          observationStartedAt: startedAt,
          wakeTime: '07:00',
        ),
        isFalse,
      );
      expect(
        storage.isAdaptivePlanningEligible(
          now: DateTime(2026, 8, 17, 10),
          observationStartedAt: startedAt,
          wakeTime: '07:00',
        ),
        isTrue,
      );
      expect(
        storage.isAdaptivePlanningEligible(
          now: DateTime(2026, 8, 18, 6, 59),
          observationStartedAt: startedAt,
          wakeTime: '07:00',
        ),
        isFalse,
      );
      expect(
        storage.isAdaptivePlanningEligible(
          now: DateTime(2026, 8, 18, 7),
          observationStartedAt: startedAt,
          wakeTime: '07:00',
        ),
        isTrue,
      );
    });

    test('cloud backup table contract covers every user-owned table', () {
      expect(
        StorageService.cloudBackupTableNames,
        containsAll(<String>[
          'app_events',
          'app_settings',
          'survey_details',
          'user_profile_snapshots',
          'smoking_events',
          'task_assignments',
          'mentor_messages',
          'medications',
          'medication_dose_log',
          'failure_triggers',
          'notification_history',
        ]),
      );
      expect(
        StorageService.cloudBackupTableNames,
        isNot(contains('subscription_state')),
      );
    });
  });

  group('loadCurrentBarrierMinutes (regression coverage)', () {
    test(
      'a call issued while another is still running reuses that call\'s in-flight future, even when given a different `now`',
      () async {
        // Regression coverage: the read-evolve-write inside this method
        // used to run fully unguarded on every call. On the exact day the
        // barrier is due to evolve, two overlapping calls could interleave
        // so the second one reads the just-reset weekStart (written by the
        // first call's completed write) before reading the not-yet-
        // -evolved stored minutes, takes the "less than 7 days" early
        // return, and hands back its own stale pre-evolution local value —
        // the database itself stays correct, but that one caller briefly
        // sees the old number.
        //
        // evolveWeeklyBarrierMinutes is fully deterministic (no jitter),
        // so two genuinely independent read-evolve-writes fed the same
        // stored data would coincidentally land on the same number anyway
        // -- comparing output values alone can't tell a shared future
        // apart from two separate correct runs. What CAN prove it: give
        // the two overlapping calls different `now` values that would
        // legitimately produce different behavior on their own (one is
        // safely inside the 7-day window as of the seeded weekStart, the
        // other is 30 days past it). If the second call actually shares
        // the first call's in-flight future (the fix), its own `now` is
        // never even looked at, and it must return whatever the first
        // call's `now` produced -- the seeded pre-evolution value.
        final storage = StorageService();
        final weekStart = DateTime(2026, 1, 1);
        await storage.saveSetting('current_barrier_minutes', '30');
        await storage.saveSetting(
          'current_barrier_week_start',
          weekStart.toIso8601String(),
        );

        // Issued synchronously, before the event loop gets a chance to run
        // either one's async body -- this is what makes `second` genuinely
        // overlap `first` rather than running strictly after it.
        final first = storage.loadCurrentBarrierMinutes(
          now: weekStart.add(const Duration(days: 2)), // inside the window
        );
        final second = storage.loadCurrentBarrierMinutes(
          now: weekStart.add(const Duration(days: 30)), // well past it
        );

        final results = await Future.wait([first, second]);

        expect(
          results[0],
          30,
          reason: 'still inside the 7-day window, so the seeded value holds',
        );
        expect(
          results[1],
          results[0],
          reason:
              'a call overlapping an already-running one must resolve to '
              "the first call's result -- its own `now` (30 days past the "
              'window, which on its own would trigger evolution) must be '
              'ignored, not used to run an independent read-evolve-write',
        );
      },
    );

    test(
      'a call issued after the previous one already completed starts a fresh read, not a stale cached future',
      () async {
        final storage = StorageService();
        await storage.saveSetting('current_barrier_minutes', '30');
        await storage.saveSetting(
          'current_barrier_week_start',
          DateTime.now().toIso8601String(),
        );

        final first = await storage.loadCurrentBarrierMinutes();
        expect(first, 30);

        // Evolve it "manually" the way a background isolate or a second
        // StorageService instance would, then confirm a later call on this
        // same instance picks up the new value rather than replaying a
        // cached in-flight future from the first, already-finished call.
        await storage.saveSetting('current_barrier_minutes', '45');
        final second = await storage.loadCurrentBarrierMinutes();
        expect(second, 45);
      },
    );
  });
}
