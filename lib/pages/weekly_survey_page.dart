import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/respiratory_burden_engine.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import 'breath_test_page.dart';
import 'cough_test_page.dart';
import 'home_page.dart';
import '../services/behavior_engine.dart';
import '../services/storage_service.dart';
import '../widgets/share_app_sheet.dart';
import '../widgets/consecutive_smoking_section.dart';
import '../widgets/packs_per_day_section.dart';
import '../widgets/survey_section_header.dart';

class WeeklySurveyPage extends StatefulWidget {
  final bool navigateToHomeAfterSave;
  final String? nameSeed;

  /// True when this page was opened because the weekly survey is overdue
  /// and completing it is required, rather than a voluntary/optional visit
  /// (menu button, post-breath-test prompt). When true, the system/gesture
  /// back button is blocked so the requirement can't be skipped for free —
  /// consistent with [MandatoryTaskPage]'s PopScope(canPop: false).
  final bool isMandatory;

  const WeeklySurveyPage({
    super.key,
    this.navigateToHomeAfterSave = false,
    this.nameSeed,
    this.isMandatory = false,
  });

  @override
  State<WeeklySurveyPage> createState() => _WeeklySurveyPageState();
}

class _WeeklySurveyPageState extends State<WeeklySurveyPage> {
  final StorageService _storageService = StorageService();
  final BehaviorEngine _behaviorEngine = BehaviorEngine();
  String _mood = 'Orta';
  String _packOption = '1 paketten az';
  String? _consecutiveSmokingHabit;
  String? _consecutiveSmokingCount;
  String _deltaVsLastWeek = 'same';

  int _lapseCount = 0;

  /// The hardest single moment of the week. Was two questions — an average
  /// and a peak — of which only the peak was ever scored, and in the quick
  /// survey the peak was just the average plus two.
  int _cravingPeak = 5;

  /// Which withdrawal symptoms and which triggers the user reports. Both
  /// used to be numeric grids the survey filled in itself: five severities
  /// that were all `isBad ? 2 : 1`, and seven day-counts of which five were
  /// fixed constants.
  final Set<String> _withdrawalSymptoms = <String>{};
  final Set<String> _triggers = <String>{};

  static const List<String> withdrawalSymptomKeys = [
    'irritability',
    'anxiety',
    'sleepProblem',
    'concentrationProblem',
    'appetiteIncrease',
  ];

  static const List<String> triggerKeys = [
    'coffee',
    'meal',
    'driving',
    'stress',
    'phone',
    'social',
    'alcohol',
  ];

  int _selfEfficacy = 6;
  int _motivation = 7;

  /// Filled from the user's actual task outcomes rather than asked. The
  /// survey used to derive it from the mood dropdown.
  int _weeklyCompletionRate = 6;

  final int _dailyBreathTestTarget = 1;
  String _lunchTime = '12:30';
  String _dinnerTime = '19:00';

  /// 0 = no trouble at all, which is where this now starts. It defaulted to
  /// 2, so anyone who left it alone was recorded as breathless walking on
  /// the flat.
  int _mmrcGrade = 0;
  int _catCough = 1;
  int _catBreathlessnessStairs = 1;
  int _catSleepQualityResp = 1;
  int _catEnergyLevelResp = 1;
  int _warningNightBreathlessnessDays = 0;

  /// Guards the save button. Without it two quick taps ran the whole submit
  /// chain twice and wrote two weekly survey records, skewing the weekly
  /// averages and streaks. `SurveyWizard` already had this lock; the weekly
  /// form never got it.
  bool _submitting = false;

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

  static const List<Map<String, String>> _workDayOptions = [
    {'key': 'Mon', 'labelKey': 'dayMonShort'},
    {'key': 'Tue', 'labelKey': 'dayTueShort'},
    {'key': 'Wed', 'labelKey': 'dayWedShort'},
    {'key': 'Thu', 'labelKey': 'dayThuShort'},
    {'key': 'Fri', 'labelKey': 'dayFriShort'},
    {'key': 'Sat', 'labelKey': 'daySatShort'},
    {'key': 'Sun', 'labelKey': 'daySunShort'},
  ];

  String get _resolvedPacksPerDay => _packOption;

  /// Last week's score, read before this week's record is written so the
  /// summary at the end can say which way things moved. Null on the first
  /// weekly survey.
  int? _previousWeeklyScore;

  @override
  void initState() {
    super.initState();
    _loadPriorContext();
  }

  /// Plan adherence comes from the tasks the user answered over the past
  /// week, not from a question. Asking someone to rate their own compliance
  /// gets an opinion; the task log already holds the fact.
  Future<void> _loadPriorContext() async {
    final rate = await _storageService.taskSuccessRateSince(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final records = await _storageService.loadSurveyHistory();
    int? previous;
    for (final record in records.reversed) {
      if (record.type == 'weekly') {
        previous = record.riskScore;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _weeklyCompletionRate = (rate * 10).round().clamp(0, 10);
      _previousWeeklyScore = previous;
    });
  }

  /// Set by [_saveWeeklySurvey] so the summary can report the recommended
  /// mode without scoring the same answers a second time.
  Map<String, dynamic> _lastEvaluation = const {};

  Future<SurveyRecord> _saveWeeklySurvey() async {
    // Read everything from `context` before the first await below — this
    // function has no `mounted`/`context.mounted` guard of its own (its
    // callers do), so BuildContext must not be touched after an async gap.
    final unnamedUserLabel = context.t('unnamedUser');
    final weeklyRecordTitle = context.t('weeklyRecordTitle');

    final now = DateTime.now();
    final recordId = now.millisecondsSinceEpoch.toString();
    final weeklyPayload = _buildWeeklyPayload();
    // Single source of truth for weekly risk scoring: the same formula the
    // home dashboard uses (BehaviorEngine.evaluateWeeklySurveyRisk), so the
    // score/level shown right after submitting can never disagree with the
    // score/level shown later on the dashboard for the same data.
    final profileContext = await _storageService.loadMergedProfileContext();
    final weeklyEvaluation = _behaviorEngine.evaluateWeeklySurveyRisk(
      weeklyPayload,
      profileContext: profileContext,
    );
    _lastEvaluation = weeklyEvaluation;
    final weeklyRiskScore = (weeklyEvaluation['weeklyRiskScore'] as num)
        .toInt();
    final weeklyRiskLevel = weeklyEvaluation['weeklyRiskLevel'].toString();
    final effectiveDailyBreathTarget = _resolveEffectiveDailyBreathTarget(
      weeklyPayload,
    );
    final latestUserName = await _resolveLatestUserName(unnamedUserLabel);
    final record = SurveyRecord(
      id: recordId,
      completedAt: now,
      type: 'weekly',
      title: weeklyRecordTitle,
      name: latestUserName,
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
      // The survey asks which situations set the user off and this field is
      // where the profile keeps them; it used to be handed an empty list
      // every week, so the answer was collected and discarded.
      triggers: _triggers.toList(),
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

    return record;
  }

  /// Everything the risk model is scored on.
  ///
  /// There used to be two of these: a long "detailed" one, and a "quick" one
  /// that filled most of the same fields with constants derived from a single
  /// mood dropdown — seven trigger day-counts, five withdrawal severities,
  /// medication adherence, family support, four of the eight respiratory
  /// items. Those numbers reached the scoring engine indistinguishable from
  /// answers. Only the detailed mode ever asked them, and it was not the
  /// default. Now there is one survey and every field in it was answered.
  Map<String, dynamic> _buildWeeklyPayload() {
    return {
      'avgCigarettesPerDay': _estimatedDailyCigarettes(_resolvedPacksPerDay),
      'deltaVsLastWeek': _deltaVsLastWeek,
      'lapseCount': _lapseCount,
      'cravingPeak': _cravingPeak,
      'mood': _mood,
      'withdrawal': _withdrawalSymptoms.toList(),
      'triggers': _triggers.toList(),
      'selfEfficacy': _selfEfficacy,
      'motivation': _motivation,
      'task': {
        'weeklyCompletionRate': _weeklyCompletionRate,
        'dailyBreathTestTarget': _dailyBreathTestTarget,
      },
      'respiratory': {
        'mmrcGrade': _mmrcGrade,
        // Only the items actually put to the user. The engine averages over
        // what it finds here, so leaving one out costs nothing but inventing
        // one would cost the score its meaning.
        'catLike': {
          'cough': _catCough,
          'breathlessnessStairs': _catBreathlessnessStairs,
          'sleepQualityResp': _catSleepQualityResp,
          'energyLevelResp': _catEnergyLevelResp,
        },
        'warningSigns': {
          'increasedNightBreathlessnessDays': _warningNightBreathlessnessDays,
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

  // Delegates to the canonical mapping in SurveyRecord so this can never
  // drift out of sync with the pack options PacksPerDaySection actually
  // offers (this used to be an independent switch with dead cases for
  // values the UI never produces and missing cases for '5'/'6'/'7+ paket',
  // silently under-scoring heavy smokers).
  int _estimatedDailyCigarettes(String packOption) {
    return SurveyRecord.packsToLegacyCigarettes(packOption);
  }

  double _calculateRespiratoryBurdenFromPayload(Map<String, dynamic> payload) =>
      RespiratoryBurdenEngine.calculateBurden(payload);

  String _resolveRespiratoryState(Map<String, dynamic> payload) =>
      RespiratoryBurdenEngine.resolveState(payload);

  int _resolveEffectiveDailyBreathTarget(Map<String, dynamic> payload) =>
      RespiratoryBurdenEngine.resolveEffectiveDailyBreathTarget(
        payload,
        _dailyBreathTestTarget,
      );

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

  /// A row of chips the user ticks. Replaces two grids of numeric sliders —
  /// five withdrawal severities and seven trigger day-counts — that the
  /// survey filled in itself. Asking "which of these happened" gets an answer
  /// per item in about the time one slider used to take.
  Widget _multiSelectChips({
    required List<String> keys,
    required Set<String> selected,
    required String labelKeyPrefix,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final key in keys)
          FilterChip(
            key: ValueKey('$labelKeyPrefix$key'),
            label: Text(context.t('$labelKeyPrefix$key')),
            selected: selected.contains(key),
            onSelected: (isOn) {
              setState(() {
                if (isOn) {
                  selected.add(key);
                } else {
                  selected.remove(key);
                }
              });
            },
          ),
      ],
    );
  }

  /// Severity asked in words rather than a bare 0-5 scale.
  ///
  /// A label reading "Cough (0-5)" leaves the user to invent what a 3 means,
  /// and two people answering the same way meant nothing comparable. Each
  /// step now names a situation, so the answer is about their week rather
  /// than about the number.
  Widget _severityChoice({
    required String titleKey,
    required String exampleKey,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(titleKey),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            context.t(exampleKey),
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var level = 0; level <= 5; level++)
                ChoiceChip(
                  key: ValueKey('${titleKey}_$level'),
                  label: Text(context.t('severityLevel$level')),
                  selected: value == level,
                  onSelected: (_) => onChanged(level),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// How often something happened, in the words people use. The scale was a
  /// 0-7 day count, which asks the user to reconstruct a week they were not
  /// counting.
  Widget _frequencyChoice({
    required String titleKey,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    // Each option maps to a representative number of days so the score keeps
    // its existing 0-7 range.
    const options = <int, String>{
      0: 'frequencyNever',
      1: 'frequencyOneOrTwoNights',
      4: 'frequencyMostNights',
      7: 'frequencyEveryNight',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(titleKey),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  key: ValueKey('${titleKey}_${entry.key}'),
                  label: Text(context.t(entry.value)),
                  selected: value == entry.key,
                  onSelected: (_) => onChanged(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRespiratoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('weeklyRespTitle'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('weeklyRespHint'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            // mMRC in plain language, and it now opens at "no trouble at
            // all". It used to default to grade 2 — breathless enough to stop
            // for breath walking on the flat — so a user who never touched it
            // was scored as symptomatic.
            Text(
              context.t('weeklyMmrcGrade'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            RadioGroup<int>(
              groupValue: _mmrcGrade,
              onChanged: (value) => setState(() => _mmrcGrade = value ?? 0),
              child: Column(
                children: [
                  for (var grade = 0; grade <= 4; grade++)
                    RadioListTile<int>(
                      key: ValueKey('mmrc_$grade'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: grade,
                      title: Text(
                        context.t('mmrcPlain$grade'),
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _severityChoice(
              titleKey: 'weeklyCough',
              exampleKey: 'weeklyCoughExample',
              value: _catCough,
              onChanged: (v) => setState(() => _catCough = v),
            ),
            _severityChoice(
              titleKey: 'weeklyBreathlessnessStairs',
              exampleKey: 'weeklyBreathlessnessStairsExample',
              value: _catBreathlessnessStairs,
              onChanged: (v) => setState(() => _catBreathlessnessStairs = v),
            ),
            // The two the user asked for: what this is costing them in sleep
            // and in energy. Both are things people notice without having to
            // measure anything.
            _severityChoice(
              titleKey: 'weeklySleepImpact',
              exampleKey: 'weeklySleepImpactExample',
              value: _catSleepQualityResp,
              onChanged: (v) => setState(() => _catSleepQualityResp = v),
            ),
            _severityChoice(
              titleKey: 'weeklyEnergyImpact',
              exampleKey: 'weeklyEnergyImpactExample',
              value: _catEnergyLevelResp,
              onChanged: (v) => setState(() => _catEnergyLevelResp = v),
            ),
            _frequencyChoice(
              titleKey: 'weeklyNightBreathlessness',
              value: _warningNightBreathlessnessDays,
              onChanged: (v) =>
                  setState(() => _warningNightBreathlessnessDays = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _resolveLatestUserName(String fallbackName) async {
    final records = await _storageService.loadSurveyHistory();
    for (final record in records.reversed) {
      if (record.name.trim().isNotEmpty) {
        return record.name.trim();
      }
    }
    return fallbackName;
  }

  /// What the answers just changed.
  ///
  /// The survey used to end by saving and navigating away, so a user who had
  /// just answered twenty questions saw nothing come back — the score moved
  /// somewhere on a dashboard they hadn't opened yet, and nothing said what
  /// their answers were used for. This names the four things that actually
  /// changed: the score, what they told us sets them off, when they're most
  /// at risk, and what tomorrow's plan looks like as a result.
  Future<void> _showWhatChanged({
    required int score,
    required Map<String, dynamic> evaluation,
  }) async {
    final previous = _previousWeeklyScore;
    final riskyHours =
        (await _storageService.loadBehaviorDashboard()).riskyHours;
    final barrierMinutes = await _storageService.loadCurrentBarrierMinutes();
    if (!mounted || !context.mounted) return;

    final lines = <String>[];

    if (previous == null) {
      lines.add(
        context.t('surveySummaryFirstScore').replaceAll('{score}', '$score'),
      );
    } else {
      final delta = score - previous;
      final key = delta == 0
          ? 'surveySummaryScoreSame'
          : delta < 0
          ? 'surveySummaryScoreDown'
          : 'surveySummaryScoreUp';
      lines.add(
        context
            .t(key)
            .replaceAll('{previous}', '$previous')
            .replaceAll('{score}', '$score')
            .replaceAll('{delta}', '${delta.abs()}'),
      );
    }

    if (_triggers.isNotEmpty) {
      final named = _triggers
          .map((key) => context.t('weeklyTrigger_$key'))
          .join(', ');
      lines.add(
        context.t('surveySummaryTriggers').replaceAll('{triggers}', named),
      );
    }

    if (riskyHours.isNotEmpty) {
      lines.add(
        context
            .t('surveySummaryRiskyHours')
            .replaceAll('{hours}', riskyHours.take(2).join(', ')),
      );
    }

    lines.add(
      context
          .t('surveySummaryPlan')
          .replaceAll('{minutes}', '$barrierMinutes')
          .replaceAll(
            '{mode}',
            context.t(
              'surveyMode_${evaluation['recommendedMode'] ?? 'balanced'}',
            ),
          ),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('surveySummaryTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(line, style: const TextStyle(height: 1.35)),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('continue')),
          ),
        ],
      ),
    );
  }

  /// Offers the shared in-app social panel after the weekly survey.
  Future<void> _offerShareProgress() async {
    await showShareAppSheet(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('weeklySurvey')),
          automaticallyImplyLeading: !widget.isMandatory,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  context.t('copdDisclaimerNotDiagnostic'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SurveySectionHeader(
                title: context.t('weeklySurveyGeneralStatus'),
                icon: Icons.smoking_rooms,
                withTopSpacing: false,
              ),
              PacksPerDaySection(
                selectedPackOption: _packOption,
                onPackOptionChanged: (value) {
                  setState(() {
                    _packOption = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _mood,
                decoration: InputDecoration(
                  labelText: context.t('weeklyMood'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'İyi',
                    child: Text(context.t('good')),
                  ),
                  DropdownMenuItem(
                    value: 'Orta',
                    child: Text(context.t('stressMedium')),
                  ),
                  DropdownMenuItem(
                    value: 'Kötü',
                    child: Text(context.t('bad')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _mood = value ?? 'Orta';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _deltaVsLastWeek,
                decoration: InputDecoration(
                  labelText: context.t('weeklyComparedLastWeek'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'decreased',
                    child: Text(context.t('weeklyDecrease')),
                  ),
                  DropdownMenuItem(
                    value: 'same',
                    child: Text(context.t('weeklySame')),
                  ),
                  DropdownMenuItem(
                    value: 'increased',
                    child: Text(context.t('weeklyIncrease')),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _deltaVsLastWeek = value ?? 'same'),
              ),
              const SizedBox(height: 12),
              _intSlider(
                label: context.t('weeklyLapseCount'),
                value: _lapseCount,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _lapseCount = v),
              ),
              // One craving question, about the worst moment. There used to
              // be two — an average and a peak — and only the peak was ever
              // scored.
              _intSlider(
                label: context.t('weeklyCravingPeak'),
                value: _cravingPeak,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _cravingPeak = v),
              ),
              SurveySectionHeader(
                title: context.t('weeklyWithdrawalSymptoms'),
                icon: Icons.mood_bad_outlined,
              ),
              Text(
                context.t('weeklyWithdrawalHint'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              _multiSelectChips(
                keys: withdrawalSymptomKeys,
                selected: _withdrawalSymptoms,
                labelKeyPrefix: 'weeklyWithdrawal_',
              ),
              SurveySectionHeader(
                title: context.t('weeklyTriggerExposure'),
                icon: Icons.local_fire_department_outlined,
              ),
              Text(
                context.t('weeklyTriggerHint'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              _multiSelectChips(
                keys: triggerKeys,
                selected: _triggers,
                labelKeyPrefix: 'weeklyTrigger_',
              ),
              SurveySectionHeader(
                title: context.t('weeklyOutlookTitle'),
                icon: Icons.psychology_outlined,
              ),
              _intSlider(
                label: context.t('weeklyMotivation'),
                value: _motivation,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _motivation = v),
              ),
              _intSlider(
                label: context.t('weeklySelfEfficacy'),
                value: _selfEfficacy,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _selfEfficacy = v),
              ),
              const SizedBox(height: 10),
              _buildRespiratoryCard(),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _lunchTime,
                decoration: InputDecoration(
                  labelText: context.t('weeklyLunchTime'),
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
                isExpanded: true,
                initialValue: _dinnerTime,
                decoration: InputDecoration(
                  labelText: context.t('weeklyDinnerTime'),
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
                title: Text(context.t('weeklyProfileChanged')),
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
                  isExpanded: true,
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
                  isExpanded: true,
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
                  isExpanded: true,
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
                  alignment: AlignmentDirectional.centerStart,
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
                  isExpanded: true,
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
                    isExpanded: true,
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
                    isExpanded: true,
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
                      isExpanded: true,
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
                      isExpanded: true,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          if (_submitting) return;
                          setState(() => _submitting = true);
                          // Body left at its original indentation so the diff stays
                          // reviewable; only the guard and the finally are new.
                          try {
                            final hasCoughTest = await _storageService
                                .hasCoughTestSince(
                                  DateTime.now().subtract(
                                    const Duration(days: 7),
                                  ),
                                );
                            if (!hasCoughTest) {
                              if (!mounted || !context.mounted) return;
                              final wantsToTest = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text(
                                    context.t('coughTestRequiredDialogTitle'),
                                  ),
                                  content: Text(
                                    context.t('coughTestRequiredDialogMessage'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: Text(context.t('coughTestSkip')),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: Text(
                                        context.t(
                                          'coughTestRequiredForWeeklySurvey',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (wantsToTest != true) {
                                return;
                              }
                              if (!mounted || !context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CoughTestPage(),
                                ),
                              );
                              if (!mounted || !context.mounted) return;
                              final nowHasTest = await _storageService
                                  .hasCoughTestSince(
                                    DateTime.now().subtract(
                                      const Duration(days: 7),
                                    ),
                                  );
                              if (!nowHasTest) {
                                // User backed out of the test without completing
                                // it — don't save the survey out from under them.
                                return;
                              }
                            }
                            if (!mounted || !context.mounted) return;
                            final unnamedUserLabel = context.t('unnamedUser');
                            final savedRecord = await _saveWeeklySurvey();
                            final score = savedRecord.riskScore;
                            final level = savedRecord.riskLevel;
                            final latestUserName = await _resolveLatestUserName(
                              unnamedUserLabel,
                            );
                            if (!mounted) return;
                            if (!context.mounted) return;

                            // Before the share offer: the user should see what their
                            // answers did before being asked to broadcast it.
                            await _showWhatChanged(
                              score: score,
                              evaluation: _lastEvaluation,
                            );
                            if (!mounted) return;
                            if (!context.mounted) return;

                            await _offerShareProgress();
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
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  child: Text(context.t('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
