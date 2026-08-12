import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/app_texts.dart';
import 'package:no_smoke/core/mentor_command_codes.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
import 'package:no_smoke/engines/wheeze_detection_engine.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/pages/breath_spirometry_result_page.dart';
import 'package:no_smoke/pages/cough_test_page.dart';
import 'package:no_smoke/pages/health_recovery_page.dart';
import 'package:no_smoke/pages/risk_result_page.dart';
import 'package:no_smoke/pages/smoked_log_consent_page.dart';
import 'package:no_smoke/pages/snoring_test_page.dart';
import 'package:no_smoke/pages/survey_review_page.dart';
import 'package:no_smoke/pages/task_smoked_confirm_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Simulates ~1000 "virtual users" across the app's 24 fully-translated
/// languages (the set in generated_language_data.dart): widget-level
/// smoke coverage for the app's user-facing screens (test results, health
/// recovery milestones, survey review/trend, duration-barrier/task
/// confirmation, smoked-log consent) plus a full sweep of every canonical
/// mentor message/command code through AppTexts' pure resolver functions —
/// covering the mentor coaching feature without needing to pump HomePage's
/// mentor card (which lives inside the documented-hang widget tree).
///
/// Deliberately excludes HomePage, SleepRoutinePage, MedicationsPage, and
/// HealthMetricsPage — all either share the documented unexplained
/// widget-test hang (home_page_mentor_card_test.dart /
/// sleep_routine_page_test.dart) or require a live, non-empty StorageService
/// to render meaningfully. Duration-barrier and health-condition-advice
/// features have no standalone widget of their own (barrier follow-ups
/// reuse TaskSmokedConfirmPage; health-condition advice is
/// notification-text-only) — both are covered via the mechanisms below
/// (TaskSmokedConfirmPage pumps, and the translation-key-existence sweep
/// implicitly covers every advice string's translated form).
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_multilingual_test')
        .path;
  }
}

const _languageCodes = [
  'de', 'ar', 'fr', 'es', 'pt', 'it', 'pl', 'ru', 'ja', 'zh',
  'ko', 'hi', 'bn', 'pa', 'te', 'mr', 'ta', 'gu', 'kn', 'ml',
  'th', 'vi', 'id', 'ms',
];

/// A handful of names chosen to stress different string lengths/scripts —
/// including a very long one, since translated labels next to a long user
/// name is a classic overflow trigger this app's CLAUDE.md explicitly warns
/// about ("Çeviriler Türkçeden uzundur... her Row Expanded/Flexible ister").
const _testNames = [
  'Ada',
  'Muhammed Abdurrahman',
  'A',
  '田中太郎',
  'Ольга Владимировна',
];

Widget _wrapWithLocale(String code, Widget child) {
  return MaterialApp(
    locale: Locale(code),
    supportedLocales: [Locale(code)],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

/// The smallest screen the app still supports (matches
/// small_screen_overflow_test.dart's `smallScreen`) — translations run
/// longer than Turkish, so a row that fits in Turkish on a big test canvas
/// is exactly where overflow first shows up. A RenderFlex overflow raises a
/// FlutterError during layout, which the test binding records — takeException
/// picks it up the same way it picks up a thrown exception.
const _smallScreen = Size(320, 568);

Future<void> _useSmallScreen(WidgetTester tester) async {
  tester.view.physicalSize = _smallScreen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Languages whose script most commonly runs longer/wider than Turkish or
/// English, and thus most likely to overflow a narrow layout — checked at
/// the small-screen size, while every other language still gets full-size
/// coverage above. Keeps the sweep's total scenario count reasonable rather
/// than doubling all ~700 widget pumps at both screen sizes.
const _overflowProneCodes = {
  'de', 'ru', 'ta', 'ar', 'hi', 'bn', 'pa', 'te', 'mr', 'gu', 'kn', 'ml',
};

const _fakeCurve = <BreathFlowCurvePoint>[
  BreathFlowCurvePoint(
    millisecondsSinceOnset: 0,
    energy: 0.1,
    cumulativeEnergyIntegral: 0.1,
  ),
  BreathFlowCurvePoint(
    millisecondsSinceOnset: 500,
    energy: 0.8,
    cumulativeEnergyIntegral: 0.9,
  ),
  BreathFlowCurvePoint(
    millisecondsSinceOnset: 1000,
    energy: 0.3,
    cumulativeEnergyIntegral: 1.2,
  ),
];

/// Every canonical mentor message code AppTexts.localizeMentorMessage must
/// be able to resolve, including the composite (tone + breath note + hist
/// note) shapes joined by segmentSeparator — mirrors how
/// MentorMessageBuilder actually composes `MentorMessage.text` in
/// production, so this sweep exercises the exact string shapes a real user
/// would see, not just each code in isolation.
final _mentorMessageCodeSamples = <String>[
  MentorMessageCodes.dailyCoachWithHour,
  '${MentorMessageCodes.dailyCoachWithHour}:07-09',
  MentorMessageCodes.dailyCoachNoHour,
  MentorMessageCodes.dailySupportive,
  MentorMessageCodes.dailyNeutralWithHour,
  '${MentorMessageCodes.dailyNeutralWithHour}:14-16',
  MentorMessageCodes.dailyNeutralNoHour,
  MentorMessageCodes.breathImprovingNote,
  MentorMessageCodes.weeklyCoachPrefix,
  MentorMessageCodes.weeklySupportive,
  MentorMessageCodes.weeklyNeutralPrefix,
  MentorMessageCodes.histWorseningPrefix,
  MentorMessageCodes.histImprovedPrefix,
  MentorMessageCodes.histSimilarPrefix,
  MentorMessageCodes.reframeSuspiciousWithTitle,
  MentorMessageCodes.reframeSuspiciousNoTitle,
  MentorMessageCodes.reframeWillpower,
  MentorMessageCodes.reframeDeferredStart,
  MentorMessageCodes.reframeFollowupDeferred,
  MentorMessageCodes.reframeDurationBarrier,
  MentorMessageCodes.followUpStrugglingQuestion,
  MentorMessageCodes.followUpAckReduceTasks,
  MentorMessageCodes.followUpAckEaseBarrier,
  MentorMessageCodes.followUpAckJustTalking,
  // Composite shapes: tone body + breath note segment, as
  // MentorMessageBuilder actually joins them in production.
  '${MentorMessageCodes.dailyCoachWithHour}:07-09'
      '${MentorMessageCodes.segmentSeparator}${MentorMessageCodes.breathImprovingNote}',
  '${MentorMessageCodes.weeklyCoachPrefix}'
      '${MentorMessageCodes.segmentSeparator}${MentorMessageCodes.histImprovedPrefix}',
];

/// Quick-reply / userReply codes — resolved through
/// AppTexts.localizeMentorReplyCode, a DIFFERENT function than
/// localizeMentorMessage above (message *bodies* vs. the user's own tapped
/// reply label) — mixing them up previously produced false-positive
/// failures here, since localizeMentorMessage's switch has no cases for
/// these at all by design.
final _mentorReplyCodeSamples = <String>[
  MentorMessageCodes.quickReplyOk,
  MentorMessageCodes.quickReplyStruggling,
  MentorMessageCodes.quickReplyNoTalk,
  MentorMessageCodes.quickReplyFillWeeklySurvey,
  MentorMessageCodes.quickReplyLater,
  MentorMessageCodes.quickReplyThanks,
  MentorMessageCodes.quickReplyLetsTalk,
  MentorMessageCodes.quickReplyOkAck,
  MentorMessageCodes.quickReplyReduceTasks,
  MentorMessageCodes.quickReplyEaseBarrier,
  MentorMessageCodes.quickReplyJustTalking,
];

/// Every canonical mentor *command* code (MentorEngine's coaching commands),
/// including the parameterized/prefixed ones with representative suffixes.
final _mentorCommandCodeSamples = <String>[
  MentorCommandCodes.reductionTier75,
  MentorCommandCodes.reductionTier60,
  MentorCommandCodes.reductionTier40,
  MentorCommandCodes.reductionTierBase,
  MentorCommandCodes.breathDeclining,
  MentorCommandCodes.breathImproving,
  MentorCommandCodes.breathStable,
  MentorCommandCodes.trackReduceToday,
  MentorCommandCodes.trackCompleteThree,
  MentorCommandCodes.triggerStress,
  MentorCommandCodes.triggerCoffee,
  MentorCommandCodes.triggerAlcohol,
  MentorCommandCodes.triggerSocial,
  MentorCommandCodes.crisisProtocol,
  MentorCommandCodes.supportSingleGoal,
  MentorCommandCodes.hintHighRisk,
  MentorCommandCodes.hintMedRisk,
  MentorCommandCodes.hintLowRisk,
  '${MentorCommandCodes.adaptiveNoSmokePrefix}:45',
  '${MentorCommandCodes.adaptiveNoSmokeWindowPrefix}:07-09',
  '${MentorCommandCodes.prepWindowPrefix}:20',
  '${MentorCommandCodes.triggerDelayPrefix}:stress',
  '${MentorCommandCodes.focusRiskHourPrefix}:08',
  '${MentorCommandCodes.weeklyTargetPrefix}:12',
  '${MentorCommandCodes.hintWindowPrefix}:30',
  '${MentorCommandCodes.hintTriggerPrefix}:coffee',
  MentorCommandCodes.riskDaypartId(band: 'high', dayPart: 'morning', index: 0),
  '${MentorCommandCodes.reductionTier75}${MentorCommandCodes.toneSoftSuffix}',
  '${MentorCommandCodes.reductionTier60}${MentorCommandCodes.toneActiveSuffix}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  final failures = <String>[];
  var scenarioCount = 0;

  tearDownAll(() {
    // ignore: avoid_print
    print(
      '\n=== MULTILINGUAL SMOKE TEST: $scenarioCount scenarios across '
      '${_languageCodes.length} languages ===',
    );
    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('=== FAILURES (${failures.length}) ===');
      for (final f in failures) {
        // ignore: avoid_print
        print('- $f');
      }
    }
  });

  for (final code in _languageCodes) {
    group('locale=$code', () {
      testWidgets('BreathSpirometryResultPage renders for varied users', (
        tester,
      ) async {
        for (var i = 0; i < _testNames.length; i++) {
          final name = _testNames[i];
          final riskScore = [10, 45, 65, 85, 99][i % 5];
          final hasWheeze = i.isEven;
          scenarioCount++;

          await tester.pumpWidget(
            _wrapWithLocale(
              code,
              BreathSpirometryResultPage(
                name: name,
                riskScore: riskScore,
                riskLevel: riskScore >= 80
                    ? 'YUKSEK'
                    : riskScore >= 40
                    ? 'ORTA'
                    : 'DUSUK',
                spirometry: const SpirometryEstimate(
                  fev1EnergyIntegral: 12.5,
                  fvcEnergyIntegral: 18.2,
                  fev1FvcRatioPercent: 68.7,
                  peakFlowIndex: 54,
                  peakFlowAtMs: 320,
                  curve: _fakeCurve,
                ),
                wheeze: hasWheeze
                    ? WheezeAnalysis(
                        wheezeDetected: true,
                        severityLevel: ['mild', 'moderate', 'severe'][i % 3],
                        severityScore: 20 + i * 15,
                        wheezeBandEnergyRatio: 0.5,
                        dominantFrequencyHz: 400,
                        wheezeDurationMs: 1200,
                      )
                    : WheezeAnalysis.none,
                wheezeAdvisoryTier: hasWheeze
                    ? ['mild', 'moderate', 'severe'][i % 3]
                    : null,
              ),
            ),
          );
          await tester.pump();

          final exception = tester.takeException();
          if (exception != null) {
            failures.add(
              '[$code] BreathSpirometryResultPage name="$name" '
              'risk=$riskScore wheeze=$hasWheeze -> $exception',
            );
          }
        }
        expect(
          failures.where((f) => f.startsWith('[$code] BreathSpirometry')),
          isEmpty,
          reason: failures.join('\n'),
        );
      });

      testWidgets(
        'RiskResultPage renders for varied smoking habits (light to '
        'heavy smoker)',
        (tester) async {
          // Real packsPerDay values from SurveyRecord.packLevel — light,
          // moderate, and heavy smokers, plus the free-text-ish '7+' and
          // '3+' high-pack follow-up options.
          const packLevels = [
            '1 paketten az',
            '1 paket',
            '2 paket',
            '3 paket',
            '3+ paket',
            '5 paket',
            '7+ paket',
          ];
          for (var i = 0; i < _testNames.length; i++) {
            final name = _testNames[i];
            final riskScore = [5, 35, 55, 75, 95][i % 5];
            final packsPerDay = packLevels[i % packLevels.length];
            scenarioCount++;

            await tester.pumpWidget(
              _wrapWithLocale(
                code,
                RiskResultPage(
                  name: name,
                  riskScore: riskScore,
                  riskLevel: riskScore >= 80
                      ? 'YUKSEK'
                      : riskScore >= 40
                      ? 'ORTA'
                      : 'DUSUK',
                  packsPerDay: packsPerDay,
                  exhaleTestSeconds: 8,
                  inhaleTestSeconds: 6,
                  showBreathDisclaimer: i.isOdd,
                ),
              ),
            );
            await tester.pump();

            final exception = tester.takeException();
            if (exception != null) {
              failures.add(
                '[$code] RiskResultPage name="$name" risk=$riskScore '
                'packsPerDay="$packsPerDay" -> $exception',
              );
            }
          }
          expect(
            failures.where((f) => f.startsWith('[$code] RiskResultPage')),
            isEmpty,
            reason: failures.join('\n'),
          );
        },
      );

      testWidgets('HealthRecoveryPage renders for varied quit dates', (
        tester,
      ) async {
        final quitDates = [
          DateTime.now(), // just quit
          DateTime.now().subtract(const Duration(days: 3)),
          DateTime.now().subtract(const Duration(days: 30)),
          DateTime.now().subtract(const Duration(days: 365)),
          DateTime.now().subtract(const Duration(days: 3650)), // 10 years
        ];
        for (final quitDate in quitDates) {
          scenarioCount++;
          await tester.pumpWidget(
            _wrapWithLocale(code, HealthRecoveryPage(quitDate: quitDate)),
          );
          await tester.pump();

          final exception = tester.takeException();
          if (exception != null) {
            failures.add(
              '[$code] HealthRecoveryPage quitDate=$quitDate -> $exception',
            );
          }
        }
        expect(
          failures.where((f) => f.startsWith('[$code] HealthRecoveryPage')),
          isEmpty,
          reason: failures.join('\n'),
        );
      });

      testWidgets('SurveyReviewPage renders for varied trend directions', (
        tester,
      ) async {
        SurveyRecord record({
          required int riskScore,
          required String packsPerDay,
          int exhale = 8,
          int inhale = 6,
        }) {
          return SurveyRecord(
            id: 's_$riskScore',
            completedAt: DateTime.now(),
            type: 'weekly',
            title: 'Haftalik Anket',
            name: 'Ada',
            packsPerDay: packsPerDay,
            exhaleTestSeconds: exhale,
            inhaleTestSeconds: inhale,
            riskScore: riskScore,
            riskLevel: riskScore >= 80
                ? 'YUKSEK'
                : riskScore >= 40
                ? 'ORTA'
                : 'DUSUK',
          );
        }

        final scenarios = <(SurveyRecord, SurveyRecord?)>[
          // No previous record (first-ever survey) — light smoker.
          (record(riskScore: 50, packsPerDay: '1 paketten az'), null),
          // No previous record — heavy smoker (longest packsPerDay label,
          // stresses layout independent of any delta text).
          (record(riskScore: 85, packsPerDay: '7+ paket'), null),
          // Improving trend, light -> moderate smoker.
          (
            record(riskScore: 30, packsPerDay: '1 paket'),
            record(riskScore: 70, packsPerDay: '2 paket'),
          ),
          // Worsening trend, moderate -> heavy smoker (largest possible
          // delta in both risk score and pack level at once).
          (
            record(riskScore: 95, packsPerDay: '7+ paket'),
            record(riskScore: 10, packsPerDay: '1 paketten az'),
          ),
          // Identical (no change) — moderate smoker.
          (
            record(riskScore: 50, packsPerDay: '3 paket'),
            record(riskScore: 50, packsPerDay: '3 paket'),
          ),
          // Extreme test-duration values (very short/very long
          // exhale/inhale), still a valid combination a real user's device
          // mic could produce.
          (
            record(
              riskScore: 60,
              packsPerDay: '2 paket',
              exhale: 1,
              inhale: 1,
            ),
            record(
              riskScore: 60,
              packsPerDay: '2 paket',
              exhale: 45,
              inhale: 30,
            ),
          ),
        ];

        for (final (current, previous) in scenarios) {
          scenarioCount++;
          await tester.pumpWidget(
            _wrapWithLocale(
              code,
              SurveyReviewPage(
                currentRecord: current,
                previousRecord: previous,
              ),
            ),
          );
          await tester.pump();

          final exception = tester.takeException();
          if (exception != null) {
            failures.add(
              '[$code] SurveyReviewPage current=${current.riskScore} '
              'previous=${previous?.riskScore} -> $exception',
            );
          }
        }
        expect(
          failures.where((f) => f.startsWith('[$code] SurveyReviewPage')),
          isEmpty,
          reason: failures.join('\n'),
        );
      });

      testWidgets(
        'TaskSmokedConfirmPage renders for varied task titles '
        '(incl. duration-barrier tasks)',
        (tester) async {
          final taskTitles = [
            'Sigara icmeme suresi bariyeri',
            'ADAPTIVE_NO_SMOKE:45',
            'SURE-BARIYERI:30',
            'A', // minimal
            'Cok uzun bir gorev basligi burada kullanici arayuzunu '
                'tasma riskiyle test etmek icin bilhassa uzatilmistir',
          ];
          for (final title in taskTitles) {
            scenarioCount++;
            await tester.pumpWidget(
              _wrapWithLocale(
                code,
                TaskSmokedConfirmPage(taskTitle: title, canonicalTitle: title),
              ),
            );
            await tester.pump();

            final exception = tester.takeException();
            if (exception != null) {
              failures.add(
                '[$code] TaskSmokedConfirmPage title="$title" '
                '-> $exception',
              );
            }
          }
          expect(
            failures.where(
              (f) => f.startsWith('[$code] TaskSmokedConfirmPage'),
            ),
            isEmpty,
            reason: failures.join('\n'),
          );
        },
      );

      testWidgets('SmokedLogConsentPage renders', (tester) async {
        scenarioCount++;
        await tester.pumpWidget(
          _wrapWithLocale(code, const SmokedLogConsentPage()),
        );
        await tester.pump();

        final exception = tester.takeException();
        if (exception != null) {
          failures.add('[$code] SmokedLogConsentPage -> $exception');
        }
        expect(exception, isNull, reason: '$exception');
      });

      testWidgets('CoughTestPage renders its not-started screen', (
        tester,
      ) async {
        scenarioCount++;
        await tester.pumpWidget(_wrapWithLocale(code, const CoughTestPage()));
        await tester.pump();

        final exception = tester.takeException();
        if (exception != null) {
          failures.add('[$code] CoughTestPage -> $exception');
        }
        expect(exception, isNull, reason: '$exception');
      });

      testWidgets('SnoringTestPage renders its not-started screen', (
        tester,
      ) async {
        scenarioCount++;
        await tester.pumpWidget(
          _wrapWithLocale(code, const SnoringTestPage()),
        );
        await tester.pump();

        final exception = tester.takeException();
        if (exception != null) {
          failures.add('[$code] SnoringTestPage -> $exception');
        }
        expect(exception, isNull, reason: '$exception');
      });

      if (_overflowProneCodes.contains(code)) {
        testWidgets(
          'small-screen overflow check: result pages at 320x568',
          (tester) async {
            await _useSmallScreen(tester);
            final smallScreenScenarios = <String, Widget>{
              'RiskResultPage': const RiskResultPage(
                name: 'Muhammed Abdurrahman',
                riskScore: 85,
                riskLevel: 'YUKSEK',
                packsPerDay: '2 paketten fazla',
                exhaleTestSeconds: 8,
                inhaleTestSeconds: 6,
                showBreathDisclaimer: true,
              ),
              'BreathSpirometryResultPage': BreathSpirometryResultPage(
                name: 'Muhammed Abdurrahman',
                riskScore: 85,
                riskLevel: 'YUKSEK',
                spirometry: const SpirometryEstimate(
                  fev1EnergyIntegral: 12.5,
                  fvcEnergyIntegral: 18.2,
                  fev1FvcRatioPercent: 68.7,
                  peakFlowIndex: 54,
                  peakFlowAtMs: 320,
                  curve: _fakeCurve,
                ),
                wheeze: const WheezeAnalysis(
                  wheezeDetected: true,
                  severityLevel: 'severe',
                  severityScore: 80,
                  wheezeBandEnergyRatio: 0.6,
                  dominantFrequencyHz: 500,
                  wheezeDurationMs: 2000,
                ),
                wheezeAdvisoryTier: 'severe',
              ),
              'HealthRecoveryPage': HealthRecoveryPage(
                quitDate: DateTime.now().subtract(const Duration(days: 30)),
              ),
              'TaskSmokedConfirmPage': const TaskSmokedConfirmPage(
                taskTitle:
                    'Cok uzun bir gorev basligi burada kullanici '
                    'arayuzunu tasma riskiyle test etmek icin bilhassa '
                    'uzatilmistir',
                canonicalTitle:
                    'Cok uzun bir gorev basligi burada kullanici '
                    'arayuzunu tasma riskiyle test etmek icin bilhassa '
                    'uzatilmistir',
              ),
              'CoughTestPage': const CoughTestPage(),
              'SnoringTestPage': const SnoringTestPage(),
            };

            for (final entry in smallScreenScenarios.entries) {
              scenarioCount++;
              await tester.pumpWidget(_wrapWithLocale(code, entry.value));
              await tester.pump();

              final exception = tester.takeException();
              if (exception != null) {
                failures.add(
                  '[$code] SMALL-SCREEN ${entry.key} -> $exception',
                );
              }
            }
            expect(
              failures.where((f) => f.startsWith('[$code] SMALL-SCREEN')),
              isEmpty,
              reason: failures.join('\n'),
            );
          },
        );
      }

      if (code == 'ar') {
        testWidgets(
          'Arabic locale actually resolves RTL text direction, not just '
          'RTL-looking strings',
          (tester) async {
            scenarioCount++;
            late BuildContext capturedContext;
            await tester.pumpWidget(
              _wrapWithLocale(
                code,
                Builder(
                  builder: (context) {
                    capturedContext = context;
                    return const RiskResultPage(
                      name: 'أحمد',
                      riskScore: 60,
                      riskLevel: 'ORTA',
                    );
                  },
                ),
              ),
            );
            await tester.pump();

            final direction = Directionality.of(capturedContext);
            if (direction != TextDirection.rtl) {
              failures.add(
                '[$code] Directionality.of(context) resolved to '
                '$direction, expected TextDirection.rtl — MaterialApp\'s '
                'locale-driven direction detection may be broken for '
                'Arabic',
              );
            }
            expect(direction, TextDirection.rtl, reason: failures.join('\n'));
          },
        );
      }

      test('every mentor message code resolves without throwing or '
          'leaking a raw code string', () {
        for (final rawCode in _mentorMessageCodeSamples) {
          scenarioCount++;
          String result;
          try {
            result = AppTexts.localizeMentorMessage(code, rawCode);
          } catch (e) {
            failures.add(
              '[$code] localizeMentorMessage("$rawCode") threw: $e',
            );
            continue;
          }
          if (result.trim().isEmpty) {
            failures.add(
              '[$code] localizeMentorMessage("$rawCode") returned empty '
              'string',
            );
          }
          // A resolver that falls all the way through should never hand
          // back the raw internal code verbatim to the user.
          if (result == rawCode) {
            failures.add(
              '[$code] localizeMentorMessage("$rawCode") returned the raw '
              'code unresolved',
            );
          }
        }
        expect(
          failures.where(
            (f) => f.startsWith('[$code] localizeMentorMessage'),
          ),
          isEmpty,
          reason: failures.join('\n'),
        );
      });

      test('every mentor quick-reply code resolves without throwing or '
          'leaking a raw code string', () {
        for (final rawCode in _mentorReplyCodeSamples) {
          scenarioCount++;
          String result;
          try {
            result = AppTexts.localizeMentorReplyCode(code, rawCode);
          } catch (e) {
            failures.add(
              '[$code] localizeMentorReplyCode("$rawCode") threw: $e',
            );
            continue;
          }
          if (result.trim().isEmpty) {
            failures.add(
              '[$code] localizeMentorReplyCode("$rawCode") returned empty '
              'string',
            );
          }
          if (result == rawCode) {
            failures.add(
              '[$code] localizeMentorReplyCode("$rawCode") returned the '
              'raw code unresolved',
            );
          }
        }
        expect(
          failures.where(
            (f) => f.startsWith('[$code] localizeMentorReplyCode'),
          ),
          isEmpty,
          reason: failures.join('\n'),
        );
      });

      test('every mentor command code resolves without throwing or '
          'leaking a raw code string', () {
        for (final rawCode in _mentorCommandCodeSamples) {
          scenarioCount++;
          String result;
          try {
            result = AppTexts.localizeCanonicalTextForCode(code, rawCode);
          } catch (e) {
            failures.add(
              '[$code] localizeCanonicalTextForCode("$rawCode") threw: $e',
            );
            continue;
          }
          if (result.trim().isEmpty) {
            failures.add(
              '[$code] localizeCanonicalTextForCode("$rawCode") returned '
              'empty string',
            );
          }
        }
        expect(
          failures.where(
            (f) => f.startsWith('[$code] localizeCanonicalTextForCode'),
          ),
          isEmpty,
          reason: failures.join('\n'),
        );
      });
    });
  }
}
