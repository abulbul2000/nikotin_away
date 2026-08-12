import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:no_smoke/core/app_texts.dart';
import 'package:no_smoke/core/app_theme.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/models/user_profile_snapshot.dart';
import 'package:no_smoke/services/language_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/ui_catalog/ui_catalog_registry.dart';

const _notificationChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, (call) async {
          if (call.method == 'zonedSchedule') {
            return null;
          }
          return true;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return 1;
          }
          if (call.method == 'requestPermissions') {
            return <int, int>{0: 1, 1: 1, 2: 1, 3: 1, 7: 1, 18: 1};
          }
          return 1;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  testWidgets('Capture real rendered UI catalog for active locale', (
    tester,
  ) async {
    final activeLanguageCode = await LanguageService.loadSelectedLanguageCode();
    await AppTexts.ensureLanguageLoaded(activeLanguageCode);
    final locale =
        LanguageService.supportedLanguages[activeLanguageCode] ??
        const Locale('en');

    final storage = StorageService();

    final catalogRoot = const String.fromEnvironment(
      'UI_CATALOG_ROOT',
      defaultValue: 'ui_catalog',
    );

    final entries = UiCatalogRegistry.entries();
    final onlyScreenId = const String.fromEnvironment(
      'UI_CATALOG_SCREEN_ID',
      defaultValue: '',
    ).trim();
    final filteredEntries =
        onlyScreenId.isEmpty
            ? entries
            : entries
                .where((entry) => entry.screenId == onlyScreenId)
                .toList(growable: false);
    if (filteredEntries.isEmpty) {
      throw StateError('UI_CATALOG_SCREEN_ID not found: $onlyScreenId');
    }
    final catalogEntries = <Map<String, dynamic>>[];

    await binding.convertFlutterSurfaceToImage();

    for (final entry in filteredEntries) {
      await _prepareCatalogState(storage, entry.captureProfile);
      await tester.pumpWidget(
        _catalogShell(locale: locale, child: entry.builder()),
      );
      await tester.pump(const Duration(milliseconds: 220));
      await _applyScrollOffset(tester, entry.scrollOffset);
      await tester.pump(const Duration(milliseconds: 120));
      await binding.takeScreenshot(entry.screenId);

      catalogEntries.add(<String, dynamic>{
        'screenId': entry.screenId,
        'screenName': entry.screenName,
        'captureProfile': entry.captureProfile,
        'appLocation': entry.appLocation,
        'screenshotPath': '$catalogRoot/screens/${entry.screenId}.png',
        'sourceFiles': entry.sourceFiles,
        'uiComponents': entry.uiComponents,
        'translationKeys': entry.translationKeys,
        'styleSources': entry.styleSources,
        'themeSources': entry.themeSources,
      });
    }

    final report = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'activeLanguageCode': activeLanguageCode,
      'catalogRoot': catalogRoot,
      'screenFolder': '$catalogRoot/screens',
      'catalogFile': '$catalogRoot/catalog/screen_catalog.json',
      'screens': catalogEntries,
    };

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['ui_catalog_json'] = jsonEncode(report);
  });
}

Future<void> _applyScrollOffset(WidgetTester tester, double scrollOffset) async {
  if (scrollOffset <= 0) {
    return;
  }

  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) {
    return;
  }

  var remaining = scrollOffset;
  while (remaining > 0) {
    final double step = remaining > 280 ? 280.0 : remaining;
    await tester.drag(scrollable.first, Offset(0, -step));
    await tester.pump(const Duration(milliseconds: 150));
    remaining -= step;
  }
}

Widget _catalogShell({required Locale locale, required Widget child}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: LanguageService.supportedLanguages.values.toList(
      growable: false,
    ),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _resetCatalogData(StorageService storage) async {
  final db = await storage.database;
  const tables = <String>[
    'app_events',
    'survey_details',
    'user_profile_snapshots',
    'task_followups',
    'protocol_violations',
    'app_settings',
    'adaptive_task_events',
    'adaptive_task_state',
    'adaptive_hourly_profile',
  ];
  for (final table in tables) {
    await db.delete(table);
  }
}

Future<void> _seedCatalogData(StorageService storage) async {
  final now = DateTime.now();
  final initial = SurveyRecord(
    id: 'catalog_initial',
    completedAt: now.subtract(const Duration(days: 20)),
    type: 'initial',
    title: 'Baslangic Kaydi',
    name: 'Catalog User',
    packsPerDay: '2 paket',
    exhaleTestSeconds: 8,
    inhaleTestSeconds: 11,
    riskScore: 72,
    riskLevel: 'YUKSEK',
    consecutiveSmokingHabit: 'Evet',
    consecutiveSmokingCount: '3 adet',
  );
  final weekly = SurveyRecord(
    id: 'catalog_weekly',
    completedAt: now.subtract(const Duration(days: 3)),
    type: 'weekly',
    title: 'Haftalik Kayit',
    name: 'Catalog User',
    packsPerDay: '1 paket',
    exhaleTestSeconds: 0,
    inhaleTestSeconds: 0,
    riskScore: 58,
    riskLevel: 'ORTA',
    consecutiveSmokingHabit: 'Evet',
    consecutiveSmokingCount: '2 adet',
  );
  final breath = SurveyRecord(
    id: 'catalog_breath',
    completedAt: now.subtract(const Duration(days: 1)),
    type: 'breath_test',
    title: 'Nefes Testi',
    name: 'Catalog User',
    packsPerDay: '1 paket',
    exhaleTestSeconds: 12,
    inhaleTestSeconds: 15,
    riskScore: 54,
    riskLevel: 'ORTA',
  );

  await storage.saveSurveyRecord(initial);
  await storage.saveSurveyRecord(weekly);
  await storage.saveSurveyRecord(breath);

  await storage.saveSurveyDetail(
    recordId: initial.id,
    triggers: const ['Kahve', 'Stres'],
    healthConditions: const ['Astim'],
    firstCigaretteRange: '10-30',
    smokeFreeRange: '30-60',
    profession: 'Mühendis',
    sleepTime: '23:00',
    wakeTime: '07:00',
    stressLevel: 'Orta',
    quitReason: 'Sagligim icin',
    workStart: '09:00',
    workEnd: '18:00',
    workplaceSmokingRule: 'Hayır',
    workingDays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    breakWindows: const <Map<String, String>>[
      {'start': '12:30', 'end': '13:00'},
    ],
    weekendSmokingPattern: 'Ayni',
  );

  await storage.saveSurveyDetail(
    recordId: weekly.id,
    triggers: const ['Stres'],
    healthConditions: const [],
    stressLevel: 'Orta',
    weeklyPayload: <String, dynamic>{
      'avgCigarettesPerDay': 9,
      'task': <String, dynamic>{
        'dailyBreathTestTarget': 1,
        'weeklyCompletionRate': 7,
      },
      'respiratory': <String, dynamic>{
        'mmrcGrade': 2,
        'catLike': <String, dynamic>{
          'cough': 1,
          'phlegm': 1,
          'chestTightness': 1,
          'breathlessnessStairs': 2,
          'activityLimitation': 1,
          'confidenceLeavingHome': 1,
          'sleepQualityResp': 1,
          'energyLevelResp': 1,
        },
        'warningSigns': <String, dynamic>{
          'increasedNightBreathlessnessDays': 0,
          'sputumIncreaseDays': 0,
          'sputumColorChangeDays': 0,
          'wheezeDays': 0,
        },
      },
    },
  );

  await storage.saveUserProfileSnapshot(
    UserProfileSnapshot(
      id: 'catalog_profile',
      createdAt: now.subtract(const Duration(days: 20)),
      riskScore: 72,
      packsPerDay: '2 paket',
      firstCigaretteRange: '10-30',
      smokeFreeRange: '30-60',
      consecutiveSmokingHabit: 'Evet',
      consecutiveSmokingCount: '3 adet',
      triggers: const ['Kahve', 'Stres'],
      healthConditions: const ['Astim'],
      profession: 'Mühendis',
      sleepTime: '23:00',
      wakeTime: '07:00',
      latestExhaleSeconds: 12,
      latestInhaleSeconds: 15,
    ),
  );

  await storage.saveProtocolViolation(
    type: 'followup_failed',
    severity: 'medium',
    source: 'catalog_seed',
    taskTitle: 'ADAPTIVE_NO_SMOKE:45',
    details: 'Catalog seed sample violation',
  );

  await storage.saveSetting('last_respiratory_state', 'stable');
  await storage.saveSetting('last_respiratory_burden', '32');
  await storage.saveSetting('daily_breath_test_target', '1');
}

Future<void> _prepareCatalogState(
  StorageService storage,
  String captureProfile,
) async {
  switch (captureProfile) {
    case 'empty_violations':
      await _resetCatalogData(storage);
      await _seedCatalogData(storage);
      final db = await storage.database;
      await db.delete('protocol_violations');
      return;
    case 'empty_history':
    case 'empty_metrics':
      await _resetCatalogData(storage);
      return;
    case 'registration_incomplete':
      await _resetCatalogData(storage);
      await _seedCatalogData(storage);
      await storage.saveInitialRegistrationCompleted(false);
      await storage.saveIsProfileCompleted(false);
      return;
    default:
      await _resetCatalogData(storage);
      await _seedCatalogData(storage);
      await storage.saveInitialRegistrationCompleted(true);
      await storage.saveIsProfileCompleted(true);
      return;
  }
}
