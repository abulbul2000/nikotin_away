import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/breath_progress_record.dart';
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
    test('saveManualSnoringProbe always records captureSucceeded true', () async {
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
    });

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

    test(
      'id-prefix backfill classifies pre-existing rows correctly: '
      "'snoreprobe_' as overnight, 'manualsnoreprobe_' as manual",
      () async {
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
      },
    );
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
    test(
      'ADAPTIVE_NO_SMOKE:<minutes> success/smoked rows make '
      'barrierSuccessRate differ from the 0.5 no-data default',
      () async {
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
      },
    );

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
    test(
      'duration_barrier_enabled = 0 produces an empty plan',
      () async {
        final storage = StorageService();
        await storage.saveSetting('duration_barrier_enabled', '0');

        final plan = await storage.buildAdaptiveNoSmokePlan(
          now: DateTime(2026, 1, 1, 10),
          sleepAt: DateTime(2026, 1, 1, 23),
          riskyHours: const [],
        );

        expect(plan.targetTaskCount, 0);
        expect(plan.items, isEmpty);
      },
    );

    test(
      "duration_barrier_preference = 'off' produces an empty plan even "
      "when duration_barrier_enabled is left unset",
      () async {
        final storage = StorageService();
        await storage.saveSetting('duration_barrier_preference', 'off');

        final plan = await storage.buildAdaptiveNoSmokePlan(
          now: DateTime(2026, 1, 1, 10),
          sleepAt: DateTime(2026, 1, 1, 23),
          riskyHours: const [],
        );

        expect(plan.targetTaskCount, 0);
        expect(plan.items, isEmpty);
      },
    );

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
        Future<AdaptiveTaskPlan> planWithFrequency(String frequency) async {
          final storage = StorageService();
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
        const sampleSize = 10;
        final allBaseDurations = <int>{};
        var azTotal = 0;
        var ortaTotal = 0;
        var cokTotal = 0;

        for (var attempt = 0; attempt < sampleSize; attempt++) {
          final az = await planWithFrequency('az');
          final orta = await planWithFrequency('orta');
          final cok = await planWithFrequency('cok');

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

    test(
      'every duration_barrier_* saveSetting call site has a matching '
      'loadSetting reader somewhere in lib/',
      () async {
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
      },
    );
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

    test(
      'a newly saved record always carries currentSchemaVersion',
      () async {
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
      },
    );
  });
}
