import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/cough_test_record.dart';
import 'package:no_smoke/models/snoring_probe_event.dart';
import 'package:no_smoke/models/step_counter_sample.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_test').path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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

  test('persists isProfileCompleted through registration completion flag', () async {
    final storage = StorageService();

    expect(await storage.loadIsProfileCompleted(), isFalse);

    await storage.saveInitialRegistrationCompleted(true);

    expect(await storage.loadIsProfileCompleted(), isTrue);
    expect(await storage.loadInitialRegistrationCompleted(), isTrue);
  });

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

  test('markWeeklySurveyPromptedToday: işaretlendikten sonra true döner', () async {
    final storage = StorageService();
    await storage.markWeeklySurveyPromptedToday();
    expect(await storage.hasWeeklySurveyBeenPromptedToday(), isTrue);
  });

  test('markWeeklySurveyPromptedToday: geçmiş tarihten sonra false döner', () async {
    final storage = StorageService();
    // Dün için kayıt
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await storage.saveSetting(
      'last_weekly_survey_prompt_at',
      yesterday.toIso8601String(),
    );
    expect(await storage.hasWeeklySurveyBeenPromptedToday(), isFalse);
  });

  test('loadLatestConsentDecision: hiç karar verilmemişse null döner', () async {
    final storage = StorageService();
    expect(await storage.loadLatestConsentDecision('sleep_intelligence'), isNull);
  });

  test('recordConsentDecision: kaydedilen kararı doğru döner', () async {
    final storage = StorageService();
    await storage.recordConsentDecision(
      featureKey: 'sleep_intelligence',
      granted: true,
      consentTextVersion: 'v1',
    );
    final decision = await storage.loadLatestConsentDecision('sleep_intelligence');
    expect(decision, isNotNull);
    expect(decision!['granted'], isTrue);
    expect(decision['consentTextVersion'], 'v1');
    expect(decision['createdAt'], isA<DateTime>());
  });

  test('recordConsentDecision: en son karar (geri çekme dahil) döner', () async {
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
    final decision = await storage.loadLatestConsentDecision('location_intelligence');
    expect(decision!['granted'], isFalse);
  });

  test('recordConsentDecision: farklı özellikler birbirini etkilemez', () async {
    final storage = StorageService();
    await storage.recordConsentDecision(
      featureKey: 'wearable_intelligence',
      granted: true,
      consentTextVersion: 'v1',
    );
    expect(await storage.loadLatestConsentDecision('sleep_intelligence'), isNull);
  });

  test('isRecentlySedentary: yeterli örnek yoksa false döner', () async {
    final storage = StorageService();
    expect(await storage.isRecentlySedentary(), isFalse);
  });

  test('isRecentlySedentary: uzun aralıkta çok az adım varsa true döner', () async {
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
      StepCounterSample(
        id: 'b',
        createdAt: now,
        cumulativeSteps: 1050,
      ),
    );
    expect(await storage.isRecentlySedentary(), isTrue);
  });

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
      StepCounterSample(
        id: 'b',
        createdAt: now,
        cumulativeSteps: 3500,
      ),
    );
    expect(await storage.isRecentlySedentary(), isFalse);
  });

  group('buildDailyProgressReport', () {
    test('reports no evidence on a fresh install with nothing logged',
        () async {
      final storage = StorageService();

      final report = await storage.buildDailyProgressReport();

      expect(report.reductionProgress.hasEvidence, isFalse);
      expect(report.todaySmokedCount, 0);
      expect(report.latestCoughTest, isNull);
    });

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

    test('startTrialIfNeeded is a no-op once trialStartedAt is already set',
        () async {
      final storage = StorageService();

      await storage.startTrialIfNeeded();
      final first = await storage.loadTrialStartedAt();

      await Future.delayed(const Duration(milliseconds: 5));
      await storage.startTrialIfNeeded();
      final second = await storage.loadTrialStartedAt();

      expect(second, first);
    });

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

    test('loadSubscriptionState returns null when nothing was ever saved',
        () async {
      final storage = StorageService();
      final state = await storage.loadSubscriptionState();
      expect(state, isNull);
    });
  });
}
