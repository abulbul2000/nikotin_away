import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import 'breath_test_page.dart';
import 'home_page.dart';
import '../services/storage_service.dart';
import '../widgets/consecutive_smoking_section.dart';
import '../widgets/packs_per_day_section.dart';

class WeeklySurveyPage extends StatefulWidget {
  final bool navigateToHomeAfterSave;
  final String? nameSeed;

  const WeeklySurveyPage({
    super.key,
    this.navigateToHomeAfterSave = false,
    this.nameSeed,
  });

  @override
  State<WeeklySurveyPage> createState() => _WeeklySurveyPageState();
}

class _WeeklySurveyPageState extends State<WeeklySurveyPage> {
  final StorageService _storageService = StorageService();
  final TextEditingController _noteController = TextEditingController();
  bool _detailedMode = false;
  bool _autoDetailedByRisk = false;
  String _mood = 'Orta';
  String _packOption = '1 paketten az';
  String? _highPackOption;
  String? _consecutiveSmokingHabit;
  String? _consecutiveSmokingCount;
  String _deltaVsLastWeek = 'same';
  String _medicationUse = 'regular';
  bool _sideEffects = false;
  bool _usedCounselingOrQuitline = false;

  int _avgCigarettesPerDay = 8;
  int _lapseCount = 0;
  int _cravingAvg = 5;
  int _cravingMax = 7;
  int _alcoholDays = 0;
  int _socialSmokingContextDays = 1;

  int _withdrawIrritability = 1;
  int _withdrawAnxiety = 1;
  int _withdrawSleep = 1;
  int _withdrawConcentration = 1;
  int _withdrawAppetite = 1;

  int _triggerCoffeeDays = 4;
  int _triggerMealDays = 4;
  int _triggerDrivingDays = 2;
  int _triggerStressDays = 5;
  int _triggerPhoneDays = 3;
  int _triggerSocialDays = 3;
  int _triggerAlcoholDays = 1;

  int _medicationAdherence = 8;
  int _familySupport = 6;
  int _selfEfficacy = 6;
  int _motivation = 7;
  int _weeklyCompletionRate = 6;
  String _dailyTaskAdherenceLevel = 'orta';
  String _commandBurdenLevel = 'orta';
  int _dailyBreathTestTarget = 1;
  String _lunchTime = '12:30';
  String _dinnerTime = '19:00';
  int _mmrcGrade = 2;
  int _catCough = 1;
  int _catPhlegm = 1;
  int _catChestTightness = 1;
  int _catBreathlessnessStairs = 1;
  int _catActivityLimitation = 1;
  int _catConfidenceLeavingHome = 1;
  int _catSleepQualityResp = 1;
  int _catEnergyLevelResp = 1;
  int _warningNightBreathlessnessDays = 0;
  int _warningSputumIncreaseDays = 0;
  int _warningSputumColorChangeDays = 0;
  int _warningWheezeDays = 0;
  bool _profileContextChanged = false;
  String? _updatedWorkStart;
  String? _updatedWorkEnd;
  String _updatedWorkplaceSmokingRule = 'Hayır';
  final Set<String> _updatedWorkingDays = <String>{
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
  };
  bool _updatedHasSmokingBreaks = false;
  String? _updatedBreakStart1;
  String? _updatedBreakEnd1;
  bool _updatedHasSecondBreak = false;
  String? _updatedBreakStart2;
  String? _updatedBreakEnd2;
  String _updatedWeekendSmokingPattern = 'Ayni';
  String _durationBarrierPreference = 'Farketmez';
  String _durationBarrierFrequencyPreference = 'Orta';

  static const List<Map<String, String>> _workDayOptions = [
    {'key': 'Mon', 'labelKey': 'dayMonShort'},
    {'key': 'Tue', 'labelKey': 'dayTueShort'},
    {'key': 'Wed', 'labelKey': 'dayWedShort'},
    {'key': 'Thu', 'labelKey': 'dayThuShort'},
    {'key': 'Fri', 'labelKey': 'dayFriShort'},
    {'key': 'Sat', 'labelKey': 'daySatShort'},
    {'key': 'Sun', 'labelKey': 'daySunShort'},
  ];

  String get _resolvedPacksPerDay {
    if (_packOption == '3+ paket') {
      return _highPackOption ?? '4 paket';
    }
    return _packOption;
  }

  @override
  void initState() {
    super.initState();
    _prepareModeFromRecentRisk();
  }

  Future<void> _prepareModeFromRecentRisk() async {
    final records = await _storageService.loadSurveyHistory();
    SurveyRecord? latestWeekly;
    for (final record in records.reversed) {
      if (record.type == 'weekly') {
        latestWeekly = record;
        break;
      }
    }

    final recentRisk = latestWeekly?.riskScore ?? 0;
    if (recentRisk >= 60 && mounted) {
      setState(() {
        _autoDetailedByRisk = true;
        // Keep quick mode as default for lower user effort.
        _detailedMode = false;
      });
    }
  }

  Future<void> _saveWeeklySurvey() async {
    final now = DateTime.now();
    final recordId = now.millisecondsSinceEpoch.toString();
    final weeklyPayload = _detailedMode
        ? _buildWeeklyPayload()
        : _buildQuickWeeklyPayload();
    final weeklyRiskScore = _calculateWeeklyRiskScore(weeklyPayload);
    final weeklyRiskLevel = _levelFromScore(weeklyRiskScore);
    final effectiveDailyBreathTarget = _resolveEffectiveDailyBreathTarget(
      weeklyPayload,
    );
    final record = SurveyRecord(
      id: recordId,
      completedAt: now,
      type: 'weekly',
      title: context.t('weeklyRecordTitle'),
      name: 'User',
      packsPerDay: _resolvedPacksPerDay,
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: weeklyRiskScore,
      riskLevel: weeklyRiskLevel,
      consecutiveSmokingHabit: _consecutiveSmokingHabit,
      consecutiveSmokingCount: _consecutiveSmokingHabit == 'Evet'
          ? _consecutiveSmokingCount
          : null,
    );
    await _storageService.saveSurveyRecord(record);

    await _storageService.saveSurveyDetail(
      recordId: recordId,
      triggers: const [],
      healthConditions: const [],
      stressLevel: _mood,
      workStart: _profileUpdateValue(weeklyPayload, 'workStart'),
      workEnd: _profileUpdateValue(weeklyPayload, 'workEnd'),
      workplaceSmokingRule: _profileUpdateValue(
        weeklyPayload,
        'workplaceSmokingRule',
      ),
      workingDays: _profileUpdateListValue(weeklyPayload, 'workingDays'),
      breakWindows: _profileUpdateBreakWindows(weeklyPayload),
      weekendSmokingPattern: _profileUpdateValue(
        weeklyPayload,
        'weekendSmokingPattern',
      ),
      weeklyPayload: weeklyPayload,
    );
    await _storageService.saveSetting('lunch_time', _lunchTime);
    await _storageService.saveSetting('dinner_time', _dinnerTime);
    await _storageService.saveSetting(
      'daily_breath_test_target',
      effectiveDailyBreathTarget.toString(),
    );
    await _storageService.saveSetting(
      'last_respiratory_burden',
      _calculateRespiratoryBurdenFromPayload(weeklyPayload).round().toString(),
    );
    await _storageService.saveSetting(
      'last_respiratory_state',
      _resolveRespiratoryState(weeklyPayload),
    );

    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_$recordId',
        createdAt: now,
        riskScore: record.riskScore,
        packsPerDay: _resolvedPacksPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit: _consecutiveSmokingHabit ?? 'Hayır',
        consecutiveSmokingCount: _consecutiveSmokingHabit == 'Evet'
            ? _consecutiveSmokingCount
            : null,
        triggers: const [],
        healthConditions: const [],
        profession: 'Belirtilmedi',
        sleepTime: '21:00',
        wakeTime: '07:00',
        latestExhaleSeconds: 0,
        latestInhaleSeconds: 0,
      ),
    );
  }

  Map<String, dynamic> _buildWeeklyPayload() {
    return {
      'avgCigarettesPerDay': _avgCigarettesPerDay,
      'deltaVsLastWeek': _deltaVsLastWeek,
      'lapseCount': _lapseCount,
      'cravingAvg': _cravingAvg,
      'cravingMax': _cravingMax,
      'withdrawal': {
        'irritability': _withdrawIrritability,
        'anxiety': _withdrawAnxiety,
        'sleepProblem': _withdrawSleep,
        'concentrationProblem': _withdrawConcentration,
        'appetiteIncrease': _withdrawAppetite,
      },
      'triggerExposureDays': {
        'coffee': _triggerCoffeeDays,
        'meal': _triggerMealDays,
        'driving': _triggerDrivingDays,
        'stress': _triggerStressDays,
        'phone': _triggerPhoneDays,
        'social': _triggerSocialDays,
        'alcohol': _triggerAlcoholDays,
      },
      'alcoholDays': _alcoholDays,
      'socialSmokingContextDays': _socialSmokingContextDays,
      'treatment': {
        'medicationUse': _medicationUse,
        'sideEffects': _sideEffects,
        'adherence': _medicationAdherence,
      },
      'support': {
        'usedCounselingOrQuitline': _usedCounselingOrQuitline,
        'familySupport': _familySupport,
      },
      'selfEfficacy': _selfEfficacy,
      'motivation': _motivation,
      'task': {
        'weeklyCompletionRate': _weeklyCompletionRate,
        'dailyTaskAdherenceLevel': _dailyTaskAdherenceLevel,
        'commandBurdenLevel': _commandBurdenLevel,
        'dailyBreathTestTarget': _dailyBreathTestTarget,
        'mostHelpfulCategory': 'breath',
      },
      'respiratory': {
        'mmrcGrade': _mmrcGrade,
        'catLike': {
          'cough': _catCough,
          'phlegm': _catPhlegm,
          'chestTightness': _catChestTightness,
          'breathlessnessStairs': _catBreathlessnessStairs,
          'activityLimitation': _catActivityLimitation,
          'confidenceLeavingHome': _catConfidenceLeavingHome,
          'sleepQualityResp': _catSleepQualityResp,
          'energyLevelResp': _catEnergyLevelResp,
        },
        'warningSigns': {
          'increasedNightBreathlessnessDays': _warningNightBreathlessnessDays,
          'sputumIncreaseDays': _warningSputumIncreaseDays,
          'sputumColorChangeDays': _warningSputumColorChangeDays,
          'wheezeDays': _warningWheezeDays,
        },
      },
      'mealSchedule': {'lunchTime': _lunchTime, 'dinnerTime': _dinnerTime},
      'profileUpdate': {
        'changed': _profileContextChanged,
        'workStart': _profileContextChanged ? _updatedWorkStart : null,
        'workEnd': _profileContextChanged ? _updatedWorkEnd : null,
        'workplaceSmokingRule': _profileContextChanged
            ? _updatedWorkplaceSmokingRule
            : null,
        'workingDays': _profileContextChanged
            ? _updatedWorkingDays.toList()
            : <String>[],
        'breakWindows': _profileContextChanged
            ? _updatedBreakWindows()
            : <Map<String, String>>[],
        'weekendSmokingPattern': _profileContextChanged
            ? _updatedWeekendSmokingPattern
            : null,
      },
    };
  }

  Map<String, dynamic> _buildQuickWeeklyPayload() {
    final moodLower = _mood.toLowerCase();
    final isGood = moodLower == 'iyi';
    final isBad = moodLower == 'kötü' || moodLower == 'kotu';
    final packAvg = _estimatedDailyCigarettes(_resolvedPacksPerDay);
    final lapseFromConsecutive = _consecutiveSmokingHabit == 'Evet'
        ? int.tryParse(_consecutiveSmokingCount ?? '1') ?? 1
        : 0;

    final motivation = isGood
        ? 8
        : isBad
        ? 4
        : 6;
    final selfEfficacy = isGood
        ? 8
        : isBad
        ? 4
        : 6;
    final stressTriggerDays = isGood
        ? 2
        : isBad
        ? 6
        : 4;
    final cravingAvg = isGood
        ? 3
        : isBad
        ? 7
        : 5;
    final completion = isGood
        ? 8
        : isBad
        ? 4
        : 6;
    final quickRespiratoryBase = _quickRespiratoryBaselineSymptom(
      isGood: isGood,
      isBad: isBad,
    );
    final quickCatAverage =
        ((_catCough + _catBreathlessnessStairs + quickRespiratoryBase) / 3)
            .round()
            .clamp(0, 5);
    final quickMmrc = _mmrcGrade.clamp(1, 5);
    final quickWarningNight = _warningNightBreathlessnessDays.clamp(0, 7);
    final quickWarningSputumColor = _warningSputumColorChangeDays.clamp(0, 7);
    final quickWarningSputumIncrease = _warningSputumIncreaseDays.clamp(0, 7);
    final quickWarningWheeze = _warningWheezeDays.clamp(0, 7);

    return {
      'avgCigarettesPerDay': packAvg,
      'deltaVsLastWeek': isBad
          ? 'increased'
          : isGood
          ? 'decreased'
          : 'same',
      'lapseCount': lapseFromConsecutive,
      'cravingAvg': cravingAvg,
      'cravingMax': (cravingAvg + 2).clamp(0, 10),
      'withdrawal': {
        'irritability': isBad ? 2 : 1,
        'anxiety': isBad ? 2 : 1,
        'sleepProblem': isBad ? 2 : 1,
        'concentrationProblem': isBad ? 2 : 1,
        'appetiteIncrease': isBad ? 2 : 1,
      },
      'triggerExposureDays': {
        'coffee': 3,
        'meal': 3,
        'driving': 2,
        'stress': stressTriggerDays,
        'phone': 3,
        'social': 3,
        'alcohol': isBad ? 2 : 1,
      },
      'alcoholDays': isBad ? 2 : 1,
      'socialSmokingContextDays': isBad ? 4 : 2,
      'treatment': {
        'medicationUse': 'regular',
        'sideEffects': false,
        'adherence': isBad ? 5 : 7,
      },
      'support': {
        'usedCounselingOrQuitline': false,
        'familySupport': isBad ? 5 : 7,
      },
      'selfEfficacy': selfEfficacy,
      'motivation': motivation,
      'task': {
        'weeklyCompletionRate': completion,
        'dailyTaskAdherenceLevel': isGood
            ? 'cok'
            : isBad
            ? 'az'
            : 'orta',
        'commandBurdenLevel': isBad ? 'cok' : 'orta',
        'dailyBreathTestTarget': _dailyBreathTestTarget,
        'mostHelpfulCategory': 'breath',
      },
      'respiratory': {
        'mmrcGrade': quickMmrc,
        'catLike': {
          'cough': _catCough.clamp(0, 5),
          'phlegm': quickCatAverage,
          'chestTightness': quickCatAverage,
          'breathlessnessStairs': _catBreathlessnessStairs.clamp(0, 5),
          'activityLimitation': quickCatAverage,
          'confidenceLeavingHome': quickCatAverage,
          'sleepQualityResp': quickCatAverage,
          'energyLevelResp': quickCatAverage,
        },
        'warningSigns': {
          'increasedNightBreathlessnessDays': quickWarningNight,
          'sputumIncreaseDays': quickWarningSputumIncrease,
          'sputumColorChangeDays': quickWarningSputumColor,
          'wheezeDays': quickWarningWheeze,
        },
      },
      'mealSchedule': {'lunchTime': _lunchTime, 'dinnerTime': _dinnerTime},
      'profileUpdate': {
        'changed': _profileContextChanged,
        'workStart': _profileContextChanged ? _updatedWorkStart : null,
        'workEnd': _profileContextChanged ? _updatedWorkEnd : null,
        'workplaceSmokingRule': _profileContextChanged
            ? _updatedWorkplaceSmokingRule
            : null,
        'workingDays': _profileContextChanged
            ? _updatedWorkingDays.toList()
            : <String>[],
        'breakWindows': _profileContextChanged
            ? _updatedBreakWindows()
            : <Map<String, String>>[],
        'weekendSmokingPattern': _profileContextChanged
            ? _updatedWeekendSmokingPattern
            : null,
      },
      'durationBarrier': {
        'preference': _durationBarrierPreference,
        'frequencyPreference': _durationBarrierFrequencyPreference,
      },
    };
  }

  List<Map<String, String>> _updatedBreakWindows() {
    final result = <Map<String, String>>[];
    if (_updatedHasSmokingBreaks &&
        _updatedBreakStart1 != null &&
        _updatedBreakEnd1 != null &&
        _updatedBreakStart1!.isNotEmpty &&
        _updatedBreakEnd1!.isNotEmpty) {
      result.add({'start': _updatedBreakStart1!, 'end': _updatedBreakEnd1!});
    }
    if (_updatedHasSmokingBreaks &&
        _updatedHasSecondBreak &&
        _updatedBreakStart2 != null &&
        _updatedBreakEnd2 != null &&
        _updatedBreakStart2!.isNotEmpty &&
        _updatedBreakEnd2!.isNotEmpty) {
      result.add({'start': _updatedBreakStart2!, 'end': _updatedBreakEnd2!});
    }
    return result;
  }

  String? _profileUpdateValue(Map<String, dynamic> payload, String key) {
    final update = payload['profileUpdate'] as Map<String, dynamic>?;
    if (update == null || update['changed'] != true) {
      return null;
    }
    final value = update[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  List<String>? _profileUpdateListValue(
    Map<String, dynamic> payload,
    String key,
  ) {
    final update = payload['profileUpdate'] as Map<String, dynamic>?;
    if (update == null || update['changed'] != true) {
      return null;
    }
    final raw = update[key] as List<dynamic>?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw.map((item) => item.toString()).toList();
  }

  List<Map<String, String>>? _profileUpdateBreakWindows(
    Map<String, dynamic> payload,
  ) {
    final update = payload['profileUpdate'] as Map<String, dynamic>?;
    if (update == null || update['changed'] != true) {
      return null;
    }
    final raw = update['breakWindows'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) {
      return <Map<String, String>>[];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => {
            'start': item['start']?.toString() ?? '',
            'end': item['end']?.toString() ?? '',
          },
        )
        .where((item) => item['start']!.isNotEmpty && item['end']!.isNotEmpty)
        .toList();
  }

  int _quickRespiratoryBaselineSymptom({
    required bool isGood,
    required bool isBad,
  }) {
    if (isBad) {
      return 3;
    }
    if (isGood) {
      return 1;
    }
    return 2;
  }

  List<String> _timeOptions() {
    final options = <String>[];
    for (var hour = 6; hour <= 23; hour++) {
      for (final minute in const [0, 30]) {
        final hh = hour.toString().padLeft(2, '0');
        final mm = minute.toString().padLeft(2, '0');
        options.add('$hh:$mm');
      }
    }
    return options;
  }

  int _estimatedDailyCigarettes(String packOption) {
    switch (packOption) {
      case '1 paketten az':
        return 8;
      case '1 paket':
        return 20;
      case '1.5 paket':
        return 30;
      case '2 paket':
        return 40;
      case '3 paket':
        return 60;
      case '4 paket':
        return 80;
      case '5+ paket':
        return 100;
      default:
        return 12;
    }
  }

  int _calculateWeeklyRiskScore(Map<String, dynamic> payload) {
    final avgCigs = payload['avgCigarettesPerDay'] as int? ?? 0;
    final delta = payload['deltaVsLastWeek']?.toString() ?? 'same';
    final lapseCount = payload['lapseCount'] as int? ?? 0;
    final cravingMax = payload['cravingMax'] as int? ?? 0;
    final motivation = payload['motivation'] as int? ?? 0;
    final selfEfficacy = payload['selfEfficacy'] as int? ?? 0;
    final alcoholDays = payload['alcoholDays'] as int? ?? 0;
    final socialDays = payload['socialSmokingContextDays'] as int? ?? 0;

    final withdrawal =
        payload['withdrawal'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final withdrawalSum =
        (withdrawal['irritability'] as int? ?? 0) +
        (withdrawal['anxiety'] as int? ?? 0) +
        (withdrawal['sleepProblem'] as int? ?? 0) +
        (withdrawal['concentrationProblem'] as int? ?? 0) +
        (withdrawal['appetiteIncrease'] as int? ?? 0);

    final trigger =
        payload['triggerExposureDays'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final triggerSum =
        (trigger['coffee'] as int? ?? 0) +
        (trigger['meal'] as int? ?? 0) +
        (trigger['driving'] as int? ?? 0) +
        (trigger['stress'] as int? ?? 0) +
        (trigger['phone'] as int? ?? 0) +
        (trigger['social'] as int? ?? 0) +
        (trigger['alcohol'] as int? ?? 0);

    final task =
        payload['task'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final treatment =
        payload['treatment'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final completion = task['weeklyCompletionRate'] as int? ?? 0;
    final adherence = treatment['adherence'] as int? ?? 0;
    final dailyTaskAdherenceLevel =
        (task['dailyTaskAdherenceLevel']?.toString() ?? 'orta').toLowerCase();
    final mmrcGrade = (respiratory['mmrcGrade'] as int? ?? 2).clamp(1, 5);

    final catSum =
        (catLike['cough'] as int? ?? 0) +
        (catLike['phlegm'] as int? ?? 0) +
        (catLike['chestTightness'] as int? ?? 0) +
        (catLike['breathlessnessStairs'] as int? ?? 0) +
        (catLike['activityLimitation'] as int? ?? 0) +
        (catLike['confidenceLeavingHome'] as int? ?? 0) +
        (catLike['sleepQualityResp'] as int? ?? 0) +
        (catLike['energyLevelResp'] as int? ?? 0);
    final warningNight =
        (warningSigns['increasedNightBreathlessnessDays'] as int? ?? 0).clamp(
          0,
          7,
        );
    final warningSputumIncrease =
        (warningSigns['sputumIncreaseDays'] as int? ?? 0).clamp(0, 7);
    final warningSputumColor =
        (warningSigns['sputumColorChangeDays'] as int? ?? 0).clamp(0, 7);
    final warningWheeze = (warningSigns['wheezeDays'] as int? ?? 0).clamp(0, 7);

    final mmrcComponent = ((mmrcGrade - 1) / 4) * 100;
    final catComponent = (catSum / 40) * 100;
    final warningComponent =
        (((warningNight +
                        warningSputumIncrease +
                        warningSputumColor +
                        warningWheeze) /
                    28) *
                100)
            .clamp(0, 100)
            .toDouble();
    final respiratoryBurden =
        ((0.35 * mmrcComponent) +
                (0.45 * catComponent) +
                (0.20 * warningComponent))
            .clamp(0, 100)
            .toDouble();

    var c = avgCigs <= 0
        ? 0
        : avgCigs <= 5
        ? 20
        : avgCigs <= 10
        ? 40
        : avgCigs <= 20
        ? 65
        : 85;
    if (delta == 'increased') {
      c += 10;
    } else if (delta == 'decreased') {
      c -= 10;
    }
    c = c.clamp(0, 100);

    final l = (lapseCount * 15).clamp(0, 100);
    final w = ((withdrawalSum / 15) * 100).round().clamp(0, 100);
    var t = ((triggerSum / 49) * 100).round();
    if ((trigger['stress'] as int? ?? 0) >= 5) {
      t += 10;
    }
    if ((trigger['alcohol'] as int? ?? 0) >= 3) {
      t += 10;
    }
    t = t.clamp(0, 100);
    final a = (alcoholDays * 8 + socialDays * 6).clamp(0, 100);
    final m = ((10 - motivation).clamp(0, 10) * 10).clamp(0, 100);
    final s = ((10 - selfEfficacy).clamp(0, 10) * 10).clamp(0, 100);
    final p = (100 - ((0.6 * completion * 10) + (0.4 * adherence * 10)))
        .round()
        .clamp(0, 100);

    var score =
        (0.22 * c +
                0.18 * l +
                0.18 * w +
                0.14 * t +
                0.08 * a +
                0.08 * m +
                0.06 * s +
                0.06 * p)
            .round();
    score = ((0.82 * score) + (0.18 * respiratoryBurden)).round().clamp(0, 100);
    if (mmrcGrade >= 4 && warningComponent >= 50) {
      score = (score + 8).clamp(0, 100);
    }
    if (warningSputumColor >= 3 && warningNight >= 3) {
      score = (score + 6).clamp(0, 100);
    }
    if (dailyTaskAdherenceLevel == 'az') {
      score = (score + 8).clamp(0, 100);
    } else if (dailyTaskAdherenceLevel == 'cok') {
      score = (score - 6).clamp(0, 100);
    }
    if (lapseCount >= 3 && cravingMax >= 8) {
      score = (score + 12).clamp(0, 100);
    }
    if (lapseCount == 0 && selfEfficacy >= 8 && completion >= 8) {
      score = (score - 8).clamp(0, 100);
    }
    return score;
  }

  double _calculateRespiratoryBurdenFromPayload(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final mmrcGrade = (respiratory['mmrcGrade'] as int? ?? 2).clamp(1, 5);
    final mmrcComponent = ((mmrcGrade - 1) / 4) * 100;

    final catSum =
        (catLike['cough'] as int? ?? 0) +
        (catLike['phlegm'] as int? ?? 0) +
        (catLike['chestTightness'] as int? ?? 0) +
        (catLike['breathlessnessStairs'] as int? ?? 0) +
        (catLike['activityLimitation'] as int? ?? 0) +
        (catLike['confidenceLeavingHome'] as int? ?? 0) +
        (catLike['sleepQualityResp'] as int? ?? 0) +
        (catLike['energyLevelResp'] as int? ?? 0);
    final catComponent = (catSum / 40) * 100;

    final warningTotal =
        (warningSigns['increasedNightBreathlessnessDays'] as int? ?? 0) +
        (warningSigns['sputumIncreaseDays'] as int? ?? 0) +
        (warningSigns['sputumColorChangeDays'] as int? ?? 0) +
        (warningSigns['wheezeDays'] as int? ?? 0);
    final warningComponent = ((warningTotal / 28) * 100).clamp(0, 100);

    return ((0.35 * mmrcComponent) +
            (0.45 * catComponent) +
            (0.20 * warningComponent))
        .clamp(0, 100)
        .toDouble();
  }

  String _resolveRespiratoryState(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final mmrcGrade = (respiratory['mmrcGrade'] as int? ?? 2).clamp(1, 5);
    final warningNight =
        (warningSigns['increasedNightBreathlessnessDays'] as int? ?? 0).clamp(
          0,
          7,
        );
    final warningSputumColor =
        (warningSigns['sputumColorChangeDays'] as int? ?? 0).clamp(0, 7);
    final burden = _calculateRespiratoryBurdenFromPayload(payload);

    final severeCombo =
        (mmrcGrade >= 4 && warningNight >= 4) ||
        (warningNight >= 4 && warningSputumColor >= 3);
    if (burden >= 65 || severeCombo) {
      return 'clinical_review_recommended';
    }
    if (burden >= 35 || warningNight >= 3 || warningSputumColor >= 2) {
      return 'monitor_closer';
    }
    return 'stable';
  }

  int _resolveEffectiveDailyBreathTarget(Map<String, dynamic> payload) {
    final burden = _calculateRespiratoryBurdenFromPayload(payload);
    var target = _dailyBreathTestTarget;
    if (burden >= 65) {
      target = (target + 1).clamp(1, 4);
    }
    return target;
  }

  String _levelFromScore(int score) {
    if (score >= 75) {
      return 'KRİTİK';
    }
    if (score >= 50) {
      return 'YÜKSEK';
    }
    if (score >= 25) {
      return 'ORTA';
    }
    return 'DÜŞÜK';
  }

  Widget _intSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Widget _buildSurveyModeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anket modu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hizli (15 sn)'),
                  selected: !_detailedMode,
                  onSelected: (_) {
                    setState(() {
                      _detailedMode = false;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Detayli'),
                  selected: _detailedMode,
                  onSelected: (_) {
                    setState(() {
                      _detailedMode = true;
                    });
                  },
                ),
              ],
            ),
            if (_autoDetailedByRisk) ...[
              const SizedBox(height: 8),
              const Text(
                'Gecen hafta risk yuksek gorunuyor. Istersen Detayli moda gecerek daha ince ayar yapabilirsin.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRespiratoryMiniCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hizli Solunum Kontrolu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kisa modda da solunum durumunu daha dogru yansitmak icin 3 alan doldur.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _mmrcGrade,
              decoration: const InputDecoration(
                labelText: 'Nefes darligi derecesi (mMRC benzeri 1-5)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 5, child: Text('5')),
              ],
              onChanged: (value) => setState(() => _mmrcGrade = value ?? 2),
            ),
            const SizedBox(height: 8),
            _intSlider(
              label: 'Oksuruk (0-5)',
              value: _catCough,
              min: 0,
              max: 5,
              onChanged: (v) => setState(() => _catCough = v),
            ),
            _intSlider(
              label: 'Merdivende nefes darligi (0-5)',
              value: _catBreathlessnessStairs,
              min: 0,
              max: 5,
              onChanged: (v) => setState(() => _catBreathlessnessStairs = v),
            ),
            _intSlider(
              label: 'Gece artan nefes darligi gunu (0-7)',
              value: _warningNightBreathlessnessDays,
              min: 0,
              max: 7,
              onChanged: (v) =>
                  setState(() => _warningNightBreathlessnessDays = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _resolveLatestUserName() async {
    final records = await _storageService.loadSurveyHistory();
    for (final record in records.reversed) {
      if (record.name.trim().isNotEmpty) {
        return record.name.trim();
      }
    }
    return 'User';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('weeklySurvey'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSurveyModeCard(),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'Bu bolum tani testi degildir. KOAH tanisi icin spirometri ve doktor degerlendirmesi gerekir. Sonuclar takip amaclidir.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            PacksPerDaySection(
              selectedPackOption: _packOption,
              selectedHighPackOption: _highPackOption,
              onPackOptionChanged: (value) {
                setState(() {
                  _packOption = value;
                  if (value != '3+ paket') {
                    _highPackOption = null;
                  } else {
                    _highPackOption ??=
                        PacksPerDaySection.highPackOptions.first;
                  }
                });
              },
              onHighPackOptionChanged: (value) {
                setState(() {
                  _highPackOption = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mood,
              decoration: InputDecoration(
                labelText: context.t('weeklyMood'),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'İyi', child: Text(context.t('good'))),
                DropdownMenuItem(
                  value: 'Orta',
                  child: Text(context.t('stressMedium')),
                ),
                DropdownMenuItem(value: 'Kötü', child: Text(context.t('bad'))),
              ],
              onChanged: (value) {
                setState(() {
                  _mood = value ?? 'Orta';
                });
              },
            ),
            if (_detailedMode) ...[
              const SizedBox(height: 12),
              _intSlider(
                label: 'Ortalama gunluk sigara',
                value: _avgCigarettesPerDay,
                min: 0,
                max: 40,
                onChanged: (v) => setState(() => _avgCigarettesPerDay = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _deltaVsLastWeek,
                decoration: const InputDecoration(
                  labelText: 'Gecen haftaya gore',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'decreased', child: Text('Azaldi')),
                  DropdownMenuItem(value: 'same', child: Text('Ayni')),
                  DropdownMenuItem(value: 'increased', child: Text('Artti')),
                ],
                onChanged: (value) =>
                    setState(() => _deltaVsLastWeek = value ?? 'same'),
              ),
              const SizedBox(height: 12),
              _intSlider(
                label: 'Kayma sayisi (lapse)',
                value: _lapseCount,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _lapseCount = v),
              ),
              _intSlider(
                label: 'Craving ortalama (0-10)',
                value: _cravingAvg,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _cravingAvg = v),
              ),
              _intSlider(
                label: 'Craving maksimum (0-10)',
                value: _cravingMax,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _cravingMax = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yoksunluk belirtileri (0-3)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Sinirlilik',
                value: _withdrawIrritability,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawIrritability = v),
              ),
              _intSlider(
                label: 'Anksiyete',
                value: _withdrawAnxiety,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawAnxiety = v),
              ),
              _intSlider(
                label: 'Uyku problemi',
                value: _withdrawSleep,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawSleep = v),
              ),
              _intSlider(
                label: 'Konsantrasyon problemi',
                value: _withdrawConcentration,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawConcentration = v),
              ),
              _intSlider(
                label: 'Istah artisi',
                value: _withdrawAppetite,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawAppetite = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tetikleyici maruziyeti (gun/saat 0-7)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Kahve',
                value: _triggerCoffeeDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerCoffeeDays = v),
              ),
              _intSlider(
                label: 'Yemek sonrasi',
                value: _triggerMealDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerMealDays = v),
              ),
              _intSlider(
                label: 'Arac kullanimi',
                value: _triggerDrivingDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerDrivingDays = v),
              ),
              _intSlider(
                label: 'Stres',
                value: _triggerStressDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerStressDays = v),
              ),
              _intSlider(
                label: 'Telefon',
                value: _triggerPhoneDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerPhoneDays = v),
              ),
              _intSlider(
                label: 'Sosyal ortam',
                value: _triggerSocialDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerSocialDays = v),
              ),
              _intSlider(
                label: 'Alkol tetigi',
                value: _triggerAlcoholDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerAlcoholDays = v),
              ),
              _intSlider(
                label: 'Alkol kullanilan gun',
                value: _alcoholDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _alcoholDays = v),
              ),
              _intSlider(
                label: 'Sigarali sosyal ortam gunu',
                value: _socialSmokingContextDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _socialSmokingContextDays = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _medicationUse,
                decoration: const InputDecoration(
                  labelText: 'Tedavi/NRT kullanimi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Yok')),
                  DropdownMenuItem(
                    value: 'irregular',
                    child: Text('Duzenli degil'),
                  ),
                  DropdownMenuItem(value: 'regular', child: Text('Duzenli')),
                ],
                onChanged: (value) =>
                    setState(() => _medicationUse = value ?? 'regular'),
              ),
              SwitchListTile(
                title: const Text('Ilac/NRT yan etkisi yasandi'),
                value: _sideEffects,
                onChanged: (v) => setState(() => _sideEffects = v),
              ),
              SwitchListTile(
                title: const Text('Danismanlik/quitline kullanildi'),
                value: _usedCounselingOrQuitline,
                onChanged: (v) => setState(() => _usedCounselingOrQuitline = v),
              ),
              _intSlider(
                label: 'Tedavi uyumu (0-10)',
                value: _medicationAdherence,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _medicationAdherence = v),
              ),
              _intSlider(
                label: 'Aile/sosyal destek (0-10)',
                value: _familySupport,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _familySupport = v),
              ),
              _intSlider(
                label: 'Oz yeterlilik (0-10)',
                value: _selfEfficacy,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _selfEfficacy = v),
              ),
              _intSlider(
                label: 'Motivasyon (0-10)',
                value: _motivation,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _motivation = v),
              ),
              _intSlider(
                label: 'Haftalik gorev tamamlama (0-10)',
                value: _weeklyCompletionRate,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _weeklyCompletionRate = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _dailyTaskAdherenceLevel,
                decoration: const InputDecoration(
                  labelText: 'Gunluk gorevlere ne kadar uydun?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'az', child: Text('Az')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta')),
                  DropdownMenuItem(value: 'cok', child: Text('Cok')),
                ],
                onChanged: (value) =>
                    setState(() => _dailyTaskAdherenceLevel = value ?? 'orta'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _commandBurdenLevel,
                decoration: const InputDecoration(
                  labelText: 'Komutlar seni rahatsiz etti mi?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'az', child: Text('Az')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta')),
                  DropdownMenuItem(value: 'cok', child: Text('Cok')),
                ],
                onChanged: (value) =>
                    setState(() => _commandBurdenLevel = value ?? 'orta'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _dailyBreathTestTarget,
                decoration: const InputDecoration(
                  labelText: 'Gunluk nefes testi sayisi tercihin (min 1)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 kez (zorunlu minimum)'),
                  ),
                  DropdownMenuItem(value: 2, child: Text('2 kez')),
                  DropdownMenuItem(value: 3, child: Text('3 kez')),
                  DropdownMenuItem(value: 4, child: Text('4 kez')),
                ],
                onChanged: (value) =>
                    setState(() => _dailyBreathTestTarget = value ?? 1),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _mmrcGrade,
                decoration: const InputDecoration(
                  labelText: 'Nefes darligi derecesi (mMRC benzeri 1-5)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 - Sadece hizli yuruyuste/yokusta zorlanma'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('2 - Duz yolda yasitlara gore daha yavas'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('3 - Duz yolda bir sure sonra durma ihtiyaci'),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('4 - 100 metre civari yuruyuste durma'),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text('5 - Ev icinde belirgin nefes darligi'),
                  ),
                ],
                onChanged: (value) => setState(() => _mmrcGrade = value ?? 2),
              ),
              const SizedBox(height: 8),
              const Text(
                'Solunum semptom yuk (CAT benzeri 0-5)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Oksuruk',
                value: _catCough,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catCough = v),
              ),
              _intSlider(
                label: 'Balgam',
                value: _catPhlegm,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catPhlegm = v),
              ),
              _intSlider(
                label: 'Goguste sikisma',
                value: _catChestTightness,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catChestTightness = v),
              ),
              _intSlider(
                label: 'Merdiven/yokus nefes darligi',
                value: _catBreathlessnessStairs,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catBreathlessnessStairs = v),
              ),
              _intSlider(
                label: 'Gunluk aktivite kisitlanmasi',
                value: _catActivityLimitation,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catActivityLimitation = v),
              ),
              _intSlider(
                label: 'Disari cikma guveni dusuklugu',
                value: _catConfidenceLeavingHome,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catConfidenceLeavingHome = v),
              ),
              _intSlider(
                label: 'Solunuma bagli uyku bozulmasi',
                value: _catSleepQualityResp,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catSleepQualityResp = v),
              ),
              _intSlider(
                label: 'Solunuma bagli enerji dusuklugu',
                value: _catEnergyLevelResp,
                min: 0,
                max: 5,
                onChanged: (v) => setState(() => _catEnergyLevelResp = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Uyari isaretleri (haftalik gun 0-7)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Gece artan nefes darligi',
                value: _warningNightBreathlessnessDays,
                min: 0,
                max: 7,
                onChanged: (v) =>
                    setState(() => _warningNightBreathlessnessDays = v),
              ),
              _intSlider(
                label: 'Balgam artisi',
                value: _warningSputumIncreaseDays,
                min: 0,
                max: 7,
                onChanged: (v) =>
                    setState(() => _warningSputumIncreaseDays = v),
              ),
              _intSlider(
                label: 'Balgam renginde degisim',
                value: _warningSputumColorChangeDays,
                min: 0,
                max: 7,
                onChanged: (v) =>
                    setState(() => _warningSputumColorChangeDays = v),
              ),
              _intSlider(
                label: 'Hirilti/wheeze',
                value: _warningWheezeDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _warningWheezeDays = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _lunchTime,
                decoration: const InputDecoration(
                  labelText: 'Tahmini ogle yemegi saati',
                  border: OutlineInputBorder(),
                ),
                items: _timeOptions()
                    .map(
                      (time) => DropdownMenuItem<String>(
                        value: time,
                        child: Text(time),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _lunchTime = value ?? '12:30'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _dinnerTime,
                decoration: const InputDecoration(
                  labelText: 'Tahmini aksam yemegi saati',
                  border: OutlineInputBorder(),
                ),
                items: _timeOptions()
                    .map(
                      (time) => DropdownMenuItem<String>(
                        value: time,
                        child: Text(time),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _dinnerTime = value ?? '19:00'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Ilk profile gore is/uyku/calisma duzeni degisti mi?',
                ),
                value: _profileContextChanged,
                onChanged: (value) {
                  setState(() {
                    _profileContextChanged = value;
                  });
                },
              ),
              if (_profileContextChanged) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _updatedWorkStart,
                  decoration: InputDecoration(
                    labelText: context.t('updatedWorkStart'),
                    border: const OutlineInputBorder(),
                  ),
                  hint: Text(context.t('selectOption')),
                  items: _timeOptions()
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(time),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _updatedWorkStart = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _updatedWorkEnd,
                  decoration: InputDecoration(
                    labelText: context.t('updatedWorkEnd'),
                    border: const OutlineInputBorder(),
                  ),
                  hint: Text(context.t('selectOption')),
                  items: _timeOptions()
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(time),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _updatedWorkEnd = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _updatedWorkplaceSmokingRule,
                  decoration: InputDecoration(
                    labelText: context.t('updatedWorkplaceRule'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Evet',
                      child: Text(context.t('yes')),
                    ),
                    DropdownMenuItem(
                      value: 'Hayır',
                      child: Text(context.t('no')),
                    ),
                    DropdownMenuItem(
                      value: 'Sadece molalarda',
                      child: Text(context.t('onlyBreaks')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _updatedWorkplaceSmokingRule = value ?? 'Hayır';
                      if (_updatedWorkplaceSmokingRule == 'Hayır') {
                        _updatedHasSmokingBreaks = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t('workDaysLabel'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _workDayOptions.map((day) {
                    final key = day['key']!;
                    return FilterChip(
                      label: Text(context.t(day['labelKey']!)),
                      selected: _updatedWorkingDays.contains(key),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _updatedWorkingDays.add(key);
                          } else {
                            _updatedWorkingDays.remove(key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _updatedWeekendSmokingPattern,
                  decoration: InputDecoration(
                    labelText: context.t('weekendPatternLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Ayni',
                      child: Text(context.t('weekendPatternSame')),
                    ),
                    DropdownMenuItem(
                      value: 'HaftaSonuDahaFazla',
                      child: Text(context.t('weekendPatternMore')),
                    ),
                    DropdownMenuItem(
                      value: 'HaftaSonuDahaAz',
                      child: Text(context.t('weekendPatternLess')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _updatedWeekendSmokingPattern = value ?? 'Ayni';
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_updatedWorkplaceSmokingRule != 'Hayır')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('smokingBreakExists')),
                    value: _updatedHasSmokingBreaks,
                    onChanged: (value) {
                      setState(() {
                        _updatedHasSmokingBreaks = value;
                        if (!value) {
                          _updatedHasSecondBreak = false;
                          _updatedBreakStart1 = null;
                          _updatedBreakEnd1 = null;
                          _updatedBreakStart2 = null;
                          _updatedBreakEnd2 = null;
                        }
                      });
                    },
                  ),
                if (_updatedWorkplaceSmokingRule != 'Hayır' &&
                    _updatedHasSmokingBreaks) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _updatedBreakStart1,
                    decoration: InputDecoration(
                      labelText: context.t('break1Start'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(context.t('selectOption')),
                    items: _timeOptions()
                        .map(
                          (time) => DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _updatedBreakStart1 = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _updatedBreakEnd1,
                    decoration: InputDecoration(
                      labelText: context.t('break1End'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(context.t('selectOption')),
                    items: _timeOptions()
                        .map(
                          (time) => DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _updatedBreakEnd1 = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('break2Exists')),
                    value: _updatedHasSecondBreak,
                    onChanged: (value) {
                      setState(() {
                        _updatedHasSecondBreak = value;
                        if (!value) {
                          _updatedBreakStart2 = null;
                          _updatedBreakEnd2 = null;
                        }
                      });
                    },
                  ),
                  if (_updatedHasSecondBreak) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _updatedBreakStart2,
                      decoration: InputDecoration(
                        labelText: context.t('break2Start'),
                        border: const OutlineInputBorder(),
                      ),
                      hint: Text(context.t('selectOption')),
                      items: _timeOptions()
                          .map(
                            (time) => DropdownMenuItem<String>(
                              value: time,
                              child: Text(time),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _updatedBreakStart2 = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _updatedBreakEnd2,
                      decoration: InputDecoration(
                        labelText: context.t('break2End'),
                        border: const OutlineInputBorder(),
                      ),
                      hint: Text(context.t('selectOption')),
                      items: _timeOptions()
                          .map(
                            (time) => DropdownMenuItem<String>(
                              value: time,
                              child: Text(time),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _updatedBreakEnd2 = value),
                    ),
                  ],
                ],
              ],
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Hizli mod secili. Temel sorulara gore risk otomatik hesaplanir. Istersen Detayli moda gecip tum parametreleri duzenleyebilirsin.',
              ),
              const SizedBox(height: 10),
              _buildQuickRespiratoryMiniCard(),
            ],
            const SizedBox(height: 20),
            const Divider(thickness: 2),
            const SizedBox(height: 20),
            const Text(
              'Süre Bariyeri Tercihi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _durationBarrierPreference,
              decoration: const InputDecoration(
                labelText: 'Süre bariyerlerini nasıl buluyorsun?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Begeniyorum',
                  child: Text('Beğeniyorum'),
                ),
                DropdownMenuItem(
                  value: 'Farketmez',
                  child: Text('Farketmez'),
                ),
                DropdownMenuItem(
                  value: 'Begenmiyorum',
                  child: Text('Beğenmiyorum'),
                ),
                DropdownMenuItem(
                  value: 'Istemiyorum',
                  child: Text('İstemiyorum'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _durationBarrierPreference = value ?? 'Farketmez';
                });
              },
            ),
            const SizedBox(height: 12),
            if (_durationBarrierPreference != 'Istemiyorum')
              DropdownButtonFormField<String>(
                initialValue: _durationBarrierFrequencyPreference,
                decoration: const InputDecoration(
                  labelText: 'Süre bariyeri sıklığı nasıl olmalı?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Az', child: Text('Az')),
                  DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                  DropdownMenuItem(value: 'Cok', child: Text('Çok')),
                ],
                onChanged: (value) {
                  setState(() {
                    _durationBarrierFrequencyPreference = value ?? 'Orta';
                  });
                },
              ),
            ConsecutiveSmokingSection(
              consecutiveSmokingHabit: _consecutiveSmokingHabit,
              consecutiveSmokingCount: _consecutiveSmokingCount,
              onHabitChanged: (value) {
                setState(() {
                  _consecutiveSmokingHabit = value;
                  if (value != 'Evet') {
                    _consecutiveSmokingCount = null;
                  }
                });
              },
              onCountChanged: (value) {
                setState(() {
                  _consecutiveSmokingCount = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t('addNote'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final payload = _detailedMode
                      ? _buildWeeklyPayload()
                      : _buildQuickWeeklyPayload();
                  final score = _calculateWeeklyRiskScore(payload);
                  final level = _levelFromScore(score);
                  await _saveWeeklySurvey();
                  final latestUserName = await _resolveLatestUserName();
                  if (!mounted) return;
                  if (!context.mounted) return;

                  if (widget.navigateToHomeAfterSave) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          name: widget.nameSeed ?? latestUserName,
                          riskScore: score,
                          riskLevel: level,
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BreathTestPage(
                        name: latestUserName,
                        packsPerDay: _resolvedPacksPerDay,
                      ),
                    ),
                  );
                },
                child: Text(context.t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
