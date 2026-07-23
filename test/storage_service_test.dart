import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/step_counter_sample.dart';
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
}
