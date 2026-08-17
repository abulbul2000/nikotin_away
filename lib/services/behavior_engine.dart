import 'dart:math';

import '../core/text_utils.dart';
import '../models/adaptive_plan.dart';
import '../models/behavior_dashboard.dart';
import '../models/breath_test_record.dart';
import '../models/cough_test_record.dart';
import '../models/sensor_usage_event.dart';
import '../models/survey_history.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../models/user_behavior_profile.dart';

class BehaviorEngine {
  static final Random _random = Random();

  static const Map<String, int> _baseTriggerScores = {
    'Kahve': 10,
    'Yemek Sonrasi': 10,
    'Arac': 10,
    'Stres': 10,
    'Telefon': 10,
    'Sosyal Ortam': 10,
    'Alkol': 10,
  };

  static const Map<String, int> _consecutiveSmokingScores = {
    'Hayır': 0,
    '2 adet': 5,
    '3 adet': 10,
    '4 adet': 15,
    '5+ adet': 20,
  };

  static const Map<String, int> _packRiskContributions = {
    '1 paketten az': 5,
    '1 paket': 10,
    '2 paket': 20,
    '3 paket': 30,
    '3+ paket': 40,
    '4 paket': 40,
    '5 paket': 40,
    '6 paket': 40,
    '7+ paket': 40,
  };

  static const List<String> _easyTasks = [
    'Ilk sigarayi 10 dakika ertele',
    'Bir bardak su ic',
    '2 dakikalik nefes egzersizi yap',
    '10 dakika sigarasiz kal',
    'Kriz anini not et',
  ];

  static const List<String> _mediumTasks = [
    'Ilk sigarayi 25 dakika ertele',
    'Bugun bir sigarayi atla',
    '30 dakika sigarasiz kal',
    'Riskli saatte seker sakiz kullan',
    '45 dakika sigarasiz kal',
  ];

  static const List<String> _hardTasks = [
    '60 dakika sigarasiz kal',
    'Bugun 2 sigara eksik ic',
    '90 dakika sigarasiz kal',
    '120 dakika sigarasiz kal',
    'Aksam saatinde destek kisisiyle iletisim kur',
  ];

  Map<String, int> calculateTriggerScores(List<SurveyHistory> surveys) {
    final scores = <String, int>{
      for (final entry in _baseTriggerScores.entries) entry.key: entry.value,
    };

    for (final survey in surveys) {
      for (final entry in scores.entries.toList()) {
        final triggerName = entry.key;
        final wasSelected = survey.triggers.any(
          (trigger) => _normalizeTrigger(trigger) == triggerName,
        );
        final delta = wasSelected ? 5 : -1;
        scores[triggerName] = max(0, (scores[triggerName] ?? 10) + delta);
      }
    }

    return scores;
  }

  Map<String, int> calculateTriggerScoresFromSurveyRecords(
    List<SurveyRecord> surveys,
    Map<String, List<String>> triggerByRecordId,
  ) {
    final scores = <String, int>{
      for (final entry in _baseTriggerScores.entries) entry.key: entry.value,
    };

    final sorted = [...surveys]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    for (final record in sorted) {
      if (record.type != 'initial' && record.type != 'weekly') {
        continue;
      }

      final selectedTriggers = triggerByRecordId[record.id] ?? const <String>[];
      for (final key in scores.keys.toList()) {
        final selected = selectedTriggers.any(
          (item) => _normalizeTrigger(item) == key,
        );
        final nextValue = (scores[key] ?? 10) + (selected ? 5 : -1);
        scores[key] = max(0, nextValue);
      }
    }

    return scores;
  }

  int calculateConsecutiveSmokingScore({String? habit, String? count}) {
    if (habit == null ||
        habit.trim().isEmpty ||
        _normalizeText(habit) == 'hayir') {
      return 0;
    }
    return _consecutiveSmokingScores[count?.trim() ?? ''] ?? 0;
  }

  String summarizeConsecutiveSmoking({String? habit, String? count}) {
    if (habit == null ||
        habit.trim().isEmpty ||
        _normalizeText(habit) == 'hayir') {
      return 'Hayır';
    }
    if (count == null || count.trim().isEmpty) {
      return habit;
    }
    return '$habit - ${count.trim()}';
  }

  String evaluateConsecutiveSmokingTrend({
    required String? previousHabit,
    required String? previousCount,
    required String? currentHabit,
    required String? currentCount,
  }) {
    final previousScore = calculateConsecutiveSmokingScore(
      habit: previousHabit,
      count: previousCount,
    );
    final currentScore = calculateConsecutiveSmokingScore(
      habit: currentHabit,
      count: currentCount,
    );

    if (previousScore == currentScore) {
      return 'trendStable';
    }
    if (currentScore < previousScore) {
      return 'trendImproving';
    }
    return 'trendDeclining';
  }

  String evaluateConsecutiveSmokingStatus({String? habit, String? count}) {
    return summarizeConsecutiveSmoking(habit: habit, count: count);
  }

  List<String> calculateRiskyTriggers(Map<String, int> triggerScores) {
    return _selectRiskyTriggers(triggerScores);
  }

  /// Returns place ids where smoking was recorded repeatedly. Null place ids
  /// are ignored because location is optional and must never block logging.
  List<String> findRepeatedSmokingPlaceIds(
    List<String?> placeIds, {
    int minimumOccurrences = 2,
  }) {
    final counts = <String, int>{};
    for (final placeId in placeIds) {
      if (placeId == null || placeId.trim().isEmpty) {
        continue;
      }
      counts[placeId] = (counts[placeId] ?? 0) + 1;
    }
    final repeated = counts.entries
        .where((entry) => entry.value >= minimumOccurrences)
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return repeated.map((entry) => entry.key).toList();
  }

  List<String> calculateRiskyHours(List<SurveyHistory> surveys) {
    final frequency = <String, int>{};

    for (final survey in surveys) {
      final label = _groupHour(survey.hardestHour);
      if (label != null) {
        frequency[label] = (frequency[label] ?? 0) + 1;
      }
    }

    if (frequency.isEmpty) {
      return const [];
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) {
        final byFrequency = b.value.compareTo(a.value);
        if (byFrequency != 0) {
          return byFrequency;
        }
        return a.key.compareTo(b.key);
      });

    return sorted.map((entry) => entry.key).toList();
  }

  /// Ranks the two-hour windows the user is most at risk in.
  ///
  /// [smokingTimes] carries the most weight by some distance because it is
  /// the only direct evidence here: the user said they smoked, and when. The
  /// rest are proxies of varying quality — a failed task suggests a craving,
  /// heavy phone use suggests idle time, a survey timestamp only says when
  /// they happened to open the app.
  ///
  /// Its weight is set well above the proxies' *combined* total rather than
  /// just above the largest, because the proxies are not independent of one
  /// another. Opening the app, running a breath test and filling in a survey
  /// are typically one sitting, counted three times over; letting that pile
  /// up against a directly reported cigarette would aim the day's tasks at
  /// when the user opens the app instead of when they smoke.
  List<String> calculateRiskyHoursFromTimestamps({
    required List<DateTime> surveyTimes,
    required List<DateTime> appUsageTimes,
    required List<DateTime> taskFailureTimes,
    required List<DateTime> breathTestTimes,
    List<DateTime> smokingTimes = const [],
  }) {
    final frequency = <String, int>{};

    void addTimes(List<DateTime> times, int weight) {
      for (final time in times) {
        final bucket = _groupHalfHourToTwoHourWindow(time.hour, time.minute);
        frequency[bucket] = (frequency[bucket] ?? 0) + weight;
      }
    }

    addTimes(smokingTimes, 12);
    addTimes(taskFailureTimes, 4);
    addTimes(surveyTimes, 3);
    addTimes(appUsageTimes, 2);
    addTimes(breathTestTimes, 1);

    if (frequency.isEmpty) {
      return const [];
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) {
        final byWeight = b.value.compareTo(a.value);
        if (byWeight != 0) {
          return byWeight;
        }
        return a.key.compareTo(b.key);
      });

    return sorted.take(3).map((entry) => entry.key).toList();
  }

  List<Map<String, dynamic>> calculateTaskSuccessRates(
    List<TaskHistory> tasks,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final task in tasks) {
      final entry = grouped.putIfAbsent(
        task.taskTitle,
        () => {
          'taskTitle': task.taskTitle,
          'totalCount': 0,
          'successCount': 0,
          'failureCount': 0,
          'successRate': 0.0,
        },
      );

      entry['totalCount'] = (entry['totalCount'] as int) + 1;
      if (task.completed) {
        entry['successCount'] = (entry['successCount'] as int) + 1;
      } else {
        entry['failureCount'] = (entry['failureCount'] as int) + 1;
      }
      entry['successRate'] =
          (entry['successCount'] as num) / (entry['totalCount'] as num);
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) {
        final rateCompare = (b['successRate'] as double).compareTo(
          a['successRate'] as double,
        );
        if (rateCompare != 0) {
          return rateCompare;
        }
        return (a['taskTitle'] as String).compareTo(b['taskTitle'] as String);
      });

    return sorted;
  }

  Map<String, double> calculateTaskSuccessRateMap(List<TaskHistory> tasks) {
    final rates = <String, double>{};
    for (final row in calculateTaskSuccessRates(tasks)) {
      rates[row['taskTitle'] as String] = (row['successRate'] as num)
          .toDouble();
    }
    return rates;
  }

  String calculateBreathTrend(List<BreathTestRecord> breathTests) {
    if (breathTests.length < 2) {
      return 'Stable';
    }

    final ordered = [...breathTests]
      ..sort((a, b) => a.date.compareTo(b.date));
    final initialAverage = _averageBreathValue(ordered.first);
    final latestAverage = _averageBreathValue(ordered.last);

    if (latestAverage > initialAverage) {
      return 'Improving';
    }
    if (latestAverage < initialAverage) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateBreathTrendFromRecords(List<SurveyRecord> records) {
    final breathRecords =
        records.where((record) => record.type == 'breath_test').toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (breathRecords.length < 2) {
      return 'Stable';
    }

    final first =
        (breathRecords.first.exhaleTestSeconds +
            breathRecords.first.inhaleTestSeconds) /
        2;
    final last =
        (breathRecords.last.exhaleTestSeconds +
            breathRecords.last.inhaleTestSeconds) /
        2;

    if (last > first) {
      return 'Improving';
    }
    if (last < first) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateSmokingTrend(List<SurveyHistory> surveys) {
    final ordered = [...surveys]
      ..sort((a, b) => a.surveyDate.compareTo(b.surveyDate));
    final recentSurveys = ordered.length > 5
        ? ordered.sublist(ordered.length - 5)
        : ordered;

    if (recentSurveys.length < 2) {
      return 'Stable';
    }

    final initialValue = _packLevel(recentSurveys.first.packsPerDay);
    final latestValue = _packLevel(recentSurveys.last.packsPerDay);

    if (latestValue < initialValue) {
      return 'Decreasing';
    }
    if (latestValue > initialValue) {
      return 'Increasing';
    }
    return 'Stable';
  }

  String calculateSmokingTrendFromRecords(List<SurveyRecord> records) {
    final surveys =
        records
            .where(
              (record) => record.type == 'initial' || record.type == 'weekly',
            )
            .toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (surveys.length < 2) {
      return 'Stable';
    }

    final initialValue = _packLevel(surveys.first.packsPerDay);
    final latestValue = _packLevel(surveys.last.packsPerDay);

    if (latestValue < initialValue) {
      return 'Decreasing';
    }
    if (latestValue > initialValue) {
      return 'Increasing';
    }
    return 'Stable';
  }

  int calculatePackRiskContribution(String packsPerDay) {
    return _packRiskContributions[packsPerDay] ?? 5;
  }

  String calculateRiskTrend(List<SurveyHistory> surveys) {
    if (surveys.length < 2) {
      return 'Stable';
    }

    final ordered = [...surveys]
      ..sort((a, b) => a.surveyDate.compareTo(b.surveyDate));
    final initialRisk = _effectiveRiskScore(ordered.first);
    final latestRisk = _effectiveRiskScore(ordered.last);
    if (latestRisk < initialRisk) {
      return 'Improving';
    }
    if (latestRisk > initialRisk) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateConsecutiveSmokingTrend(List<SurveyHistory> surveys) {
    if (surveys.length < 2) {
      return 'noRecordYet';
    }

    final ordered = [...surveys]
      ..sort((a, b) => a.surveyDate.compareTo(b.surveyDate));
    final previousScore = calculateChainSmokingRiskContribution(
      ordered[ordered.length - 2].chainSmokingLevel,
    );
    final currentScore = calculateChainSmokingRiskContribution(
      ordered.last.chainSmokingLevel,
    );

    if (currentScore < previousScore) {
      return 'trendImproving';
    }
    if (currentScore > previousScore) {
      return 'trendDeclining';
    }
    return 'trendStable';
  }

  String evaluateConsecutiveSmokingTrendFromRecords(
    List<SurveyRecord> records,
  ) {
    final relevant = _extractRelevantSurveyRecords(records);
    if (relevant.length < 2) {
      return 'trendStable';
    }

    final previous = relevant[relevant.length - 2];
    final current = relevant.last;
    return evaluateConsecutiveSmokingTrend(
      previousHabit: previous.consecutiveSmokingHabit,
      previousCount: previous.consecutiveSmokingCount,
      currentHabit: current.consecutiveSmokingHabit,
      currentCount: current.consecutiveSmokingCount,
    );
  }

  int calculateDynamicRiskScore({
    required int baseRiskScore,
    required String smokingTrend,
    required String breathTrend,
    required String consecutiveTrend,
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    Map<String, double>? learnedWeights,
  }) {
    final weights = learnedWeights ?? const <String, double>{};
    final smokingWeight = weights['smoking'] ?? 1.0;
    final breathWeight = weights['breath'] ?? 1.0;
    final consecutiveWeight = weights['consecutive'] ?? 1.0;
    final triggerWeight = weights['trigger'] ?? 1.0;
    final hourWeight = weights['hour'] ?? 1.0;

    var score = baseRiskScore;

    if (smokingTrend == 'Increasing') {
      score += (8 * smokingWeight).round();
    } else if (smokingTrend == 'Decreasing') {
      score -= (6 * smokingWeight).round();
    }

    if (breathTrend == 'Declining') {
      score += (6 * breathWeight).round();
    } else if (breathTrend == 'Improving') {
      score -= (5 * breathWeight).round();
    }

    if (consecutiveTrend == 'trendDeclining') {
      score += (7 * consecutiveWeight).round();
    } else if (consecutiveTrend == 'trendImproving') {
      score -= (4 * consecutiveWeight).round();
    }

    score += (min(riskyTriggers.length, 3) * 2 * triggerWeight).round();
    score += (min(riskyHours.length, 2) * 2 * hourWeight).round();

    return score.clamp(0, 100);
  }

  Map<String, dynamic> evaluateWeeklySurveyRisk(
    Map<String, dynamic>? weeklyPayload, {
    Map<String, dynamic>? profileContext,
  }) {
    if (weeklyPayload == null || weeklyPayload.isEmpty) {
      // No weekly survey exists yet — before the flat 40 default, this
      // ignored the user's real initial-survey answers entirely even
      // though this component carries 40% of the first risk score. Base
      // it on what the initial survey actually captured instead: cigarette
      // volume and health risk (breath-test data is deliberately not
      // folded in here — it already has its own, correctly-weighted slot
      // in the final formula via BreathTestEngine.calculateFinalRisk).
      final packsPerDay = profileContext?['packsPerDay']?.toString();
      if (packsPerDay == null || packsPerDay.isEmpty) {
        return {
          'weeklyRiskScore': 40,
          'weeklyRiskLevel': 'medium',
          'recommendedMode': 'balanced',
          'respiratoryBurden': 25,
          'respiratoryState': 'stable',
          'topRiskDrivers': <String>[],
        };
      }

      final healthConditionCount =
          (profileContext?['healthConditions'] as List<dynamic>? ?? const [])
              .length;
      final riskyTriggerCount =
          (profileContext?['riskyTriggers'] as List<dynamic>? ?? const [])
              .length;

      final initialScore =
          (calculatePackRiskContribution(packsPerDay) +
                  (min(healthConditionCount, 4) * 6) +
                  (min(riskyTriggerCount, 3) * 4))
              .clamp(0, 100);
      final initialLevel = initialScore >= 50
          ? 'high'
          : initialScore >= 25
          ? 'medium'
          : 'low';

      return {
        'weeklyRiskScore': initialScore,
        'weeklyRiskLevel': initialLevel,
        'recommendedMode': 'balanced',
        'respiratoryBurden': 25,
        'respiratoryState': 'stable',
        'topRiskDrivers': <String>[],
      };
    }

    final avgCigs = _toInt(weeklyPayload['avgCigarettesPerDay']);
    final delta = (weeklyPayload['deltaVsLastWeek']?.toString() ?? 'same')
        .toLowerCase();
    final lapseCount = _toInt(weeklyPayload['lapseCount']);
    final motivation = _toInt(weeklyPayload['motivation']);
    final selfEfficacy = _toInt(weeklyPayload['selfEfficacy']);

    // Which withdrawal symptoms the user actually reported this week. Was a
    // 0-3 severity per symptom, all five of which the quick survey filled in
    // as `isBad ? 2 : 1` — five numbers carrying one bit of real information.
    // Now it's a list of what they ticked, and the score reflects how many.
    final reportedWithdrawal = _toStringList(weeklyPayload['withdrawal']);
    const withdrawalSymptomCount = 5;

    // Same story: seven trigger categories each carried a 0-7 day count, and
    // five of the seven were hardcoded constants. Asking "which of these set
    // you off this week" gets real answers to one question.
    final triggers = _toStringList(weeklyPayload['triggers']);
    const triggerCount = 7;

    final task =
        weeklyPayload['task'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final respiratory =
        weeklyPayload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final completion = _toInt(task['weeklyCompletionRate']);

    // 0 means "no trouble at all" and is a legitimate answer, so the grade is
    // clamped from 0 rather than 1. It used to start at 1, which meant a user
    // who never touched the control was recorded as mildly breathless.
    final mmrcGrade = _toInt(respiratory['mmrcGrade']).clamp(0, 5);

    // Only the items the user was actually asked. The survey used to carry
    // all eight and fill the unasked ones with an average of the asked ones,
    // which inflated a real answer into four fabricated ones.
    const catKeys = [
      'cough',
      'phlegm',
      'chestTightness',
      'breathlessnessStairs',
      'activityLimitation',
      'confidenceLeavingHome',
      'sleepQualityResp',
      'energyLevelResp',
    ];
    final answeredCat = catKeys.where(catLike.containsKey).toList();
    final catSum = answeredCat.fold<int>(
      0,
      (sum, key) => sum + _toInt(catLike[key]),
    );
    final warningNight = _toInt(
      warningSigns['increasedNightBreathlessnessDays'],
    ).clamp(0, 7);
    final warningSputumIncrease = _toInt(
      warningSigns['sputumIncreaseDays'],
    ).clamp(0, 7);
    final warningSputumColor = _toInt(
      warningSigns['sputumColorChangeDays'],
    ).clamp(0, 7);
    final warningWheeze = _toInt(warningSigns['wheezeDays']).clamp(0, 7);

    final mmrcComponent = (mmrcGrade / 5) * 100;
    final catComponent = answeredCat.isEmpty
        ? 0.0
        : (catSum / (answeredCat.length * 5)) * 100;
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

    var c = _consumptionScore(avgCigs);
    if (delta == 'increased') {
      c += 10;
    } else if (delta == 'decreased') {
      c -= 10;
    }
    c = c.clamp(0, 100);

    final l = (lapseCount * 15).clamp(0, 100);
    final w = ((reportedWithdrawal.length / withdrawalSymptomCount) * 100)
        .round()
        .clamp(0, 100);
    var t = ((triggers.length / triggerCount) * 100).round();
    // Stress and alcohol are the two that most reliably precede a lapse, so
    // they still weigh more than the rest.
    if (triggers.contains('stress')) {
      t += 10;
    }
    if (triggers.contains('alcohol')) {
      t += 10;
    }
    t = t.clamp(0, 100);

    // Was two separate day counts, both hardcoded. The trigger answers say
    // the same thing without asking anything extra.
    final a =
        ((triggers.contains('alcohol') ? 55 : 0) +
                (triggers.contains('social') ? 45 : 0))
            .clamp(0, 100);
    final m = ((10 - motivation).clamp(0, 10) * 10).clamp(0, 100);
    final s = ((10 - selfEfficacy).clamp(0, 10) * 10).clamp(0, 100);
    // Medication adherence used to make up 40% of this. It was never asked —
    // the survey filled it in — and medication now lives in its own tracker,
    // so plan adherence is what the user's answered tasks actually show.
    final p = (100 - (completion * 10)).round().clamp(0, 100);

    var weeklyRiskScore =
        (0.22 * c +
                0.18 * l +
                0.18 * w +
                0.14 * t +
                0.08 * a +
                0.08 * m +
                0.06 * s +
                0.06 * p)
            .round();

    weeklyRiskScore = ((0.82 * weeklyRiskScore) + (0.18 * respiratoryBurden))
        .round()
        .clamp(0, 100);

    if (mmrcGrade >= 4 && warningComponent >= 50) {
      weeklyRiskScore = (weeklyRiskScore + 8).clamp(0, 100);
    }
    if (warningSputumColor >= 3 && warningNight >= 3) {
      weeklyRiskScore = (weeklyRiskScore + 6).clamp(0, 100);
    }

    final structuralModifier = _structuralConsumptionRiskModifier(
      avgCigs: avgCigs,
      profileContext: profileContext,
    );
    weeklyRiskScore = (weeklyRiskScore + structuralModifier).clamp(0, 100);

    if (lapseCount >= 3 && _toInt(weeklyPayload['cravingPeak']) >= 8) {
      weeklyRiskScore = (weeklyRiskScore + 12).clamp(0, 100);
    }
    if (lapseCount == 0 && selfEfficacy >= 8 && completion >= 8) {
      weeklyRiskScore = (weeklyRiskScore - 8).clamp(0, 100);
    }

    final weightedDrivers = <MapEntry<String, int>>[
      MapEntry('Tuketim', c),
      MapEntry('Kayma', l),
      MapEntry('Yoksunluk', w),
      MapEntry('Tetikleyici', t),
      MapEntry('Alkol/Sosyal', a),
      MapEntry('Motivasyon dusuklugu', m),
      MapEntry('Oz yeterlilik dusuklugu', s),
      MapEntry('Plan uyumsuzlugu', p),
      MapEntry('Respiratuar yuk', respiratoryBurden.round()),
      if (structuralModifier > 0)
        MapEntry(
          'Mesai/icerik uyumsuzlugu',
          (40 + (structuralModifier * 5)).clamp(0, 100),
        ),
    ]..sort((x, y) => y.value.compareTo(x.value));

    final topDrivers = weightedDrivers
        .take(3)
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList();

    final level = weeklyRiskScore >= 75
        ? 'critical'
        : weeklyRiskScore >= 50
        ? 'high'
        : weeklyRiskScore >= 25
        ? 'medium'
        : 'low';

    final mode =
        weeklyRiskScore >= 65 ||
            lapseCount >= 2 ||
            _toInt(weeklyPayload['cravingPeak']) >= 8 ||
            respiratoryBurden >= 65
        ? 'aggressive'
        : (weeklyRiskScore < 40 && lapseCount == 0 && completion >= 7)
        ? 'protective'
        : 'balanced';

    final respiratoryState = _resolveRespiratoryState(
      burden: respiratoryBurden,
      mmrcGrade: mmrcGrade,
      warningNight: warningNight,
      warningSputumColor: warningSputumColor,
    );

    return {
      'weeklyRiskScore': weeklyRiskScore,
      'weeklyRiskLevel': level,
      'recommendedMode': mode,
      'respiratoryBurden': respiratoryBurden.round(),
      'respiratoryState': respiratoryState,
      'structuralModifier': structuralModifier,
      'topRiskDrivers': topDrivers,
    };
  }

  int _structuralConsumptionRiskModifier({
    required int avgCigs,
    Map<String, dynamic>? profileContext,
  }) {
    if (profileContext == null || profileContext.isEmpty || avgCigs <= 0) {
      return 0;
    }

    final workplaceRule =
        (profileContext['workplaceSmokingRule']?.toString() ?? '')
            .toLowerCase();
    final workStart = profileContext['workStart']?.toString();
    final workEnd = profileContext['workEnd']?.toString();
    final weekendPattern =
        (profileContext['weekendSmokingPattern']?.toString() ?? '')
            .toLowerCase();
    final workingDays =
        (profileContext['workingDays'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList();
    final breakWindows =
        (profileContext['breakWindows'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

    final workMinutes = _windowDurationMinutes(workStart, workEnd) ?? 0;
    final breakMinutes = breakWindows.fold<int>(0, (sum, item) {
      return sum +
          (_windowDurationMinutes(
                item['start']?.toString(),
                item['end']?.toString(),
              ) ??
              0);
    });
    final workingDayCount = workingDays.isEmpty ? 5 : workingDays.length;

    var modifier = 0;
    final noSmokingAtWork = workplaceRule.contains('hay');
    final onlyBreakSmoking = workplaceRule.contains('mola');

    if (workMinutes >= 300 && noSmokingAtWork) {
      if (avgCigs >= 15) {
        modifier += 6;
      } else if (avgCigs >= 10) {
        modifier += 3;
      }
    }

    if (workMinutes >= 240 && onlyBreakSmoking) {
      final breakAllowance = breakMinutes <= 0
          ? 0
          : (breakMinutes / 25).floor();
      if (breakAllowance <= 2 && avgCigs >= 18) {
        modifier += 5;
      } else if (breakAllowance <= 3 && avgCigs >= 12) {
        modifier += 2;
      }
    }

    if (workingDayCount <= 3 && avgCigs >= 20) {
      modifier += 2;
    }

    if (weekendPattern.contains('fazla')) {
      modifier += 4;
    } else if (weekendPattern.contains('az')) {
      modifier -= 2;
    }

    return modifier.clamp(-4, 12);
  }

  int? _windowDurationMinutes(String? startTime, String? endTime) {
    final start = _parseMinutes(startTime);
    final end = _parseMinutes(endTime);
    if (start == null || end == null) {
      return null;
    }

    if (end >= start) {
      return end - start;
    }
    return (24 * 60) - start + end;
  }

  int? _parseMinutes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return (hour.clamp(0, 23) * 60) + minute.clamp(0, 59);
  }

  Map<String, double> learnDynamicWeightsFromRecentHistory({
    required List<TaskHistory> taskHistory,
    required List<SurveyRecord> breathRecords,
    required List<SurveyRecord> surveyRecords,
  }) {
    final recentTasks = taskHistory.length > 7
        ? taskHistory.sublist(taskHistory.length - 7)
        : taskHistory;
    final failureCount = recentTasks.where((item) => !item.completed).length;
    final taskCount = recentTasks.length;
    final failureRate = taskCount == 0 ? 0.0 : failureCount / taskCount;

    final recentBreath = breathRecords.length > 7
        ? breathRecords.sublist(breathRecords.length - 7)
        : breathRecords;
    final breathValues = recentBreath
        .map(
          (item) => ((item.exhaleTestSeconds + item.inhaleTestSeconds) / 2)
              .toDouble(),
        )
        .toList();
    final breathVolatility = _stdDev(breathValues);

    final recentSurvey = surveyRecords.length > 7
        ? surveyRecords.sublist(surveyRecords.length - 7)
        : surveyRecords;
    final packLevels = recentSurvey
        .map((item) => _packLevel(item.packsPerDay))
        .toList();
    final packSlope = packLevels.length < 2
        ? 0.0
        : (packLevels.last - packLevels.first).toDouble();

    final smokingWeight = (1.0 + (packSlope > 0 ? 0.18 : 0.0)).clamp(
      0.85,
      1.35,
    );
    final breathWeight = (1.0 + ((breathVolatility / 4.0).clamp(0.0, 0.28)))
        .clamp(0.85, 1.35);
    final consecutiveWeight = (1.0 + ((failureRate - 0.35).clamp(-0.2, 0.3)))
        .clamp(0.85, 1.35);
    final triggerWeight = (1.0 + ((failureRate - 0.25).clamp(-0.15, 0.25)))
        .clamp(0.85, 1.35);
    final hourWeight = (1.0 + ((failureRate - 0.30).clamp(-0.15, 0.22))).clamp(
      0.85,
      1.35,
    );

    return {
      'smoking': smokingWeight,
      'breath': breathWeight,
      'consecutive': consecutiveWeight,
      'trigger': triggerWeight,
      'hour': hourWeight,
    };
  }

  List<String> buildRiskExplanation({
    required int baseRisk,
    required int dynamicCoreRisk,
    required int personalizedAdjustment,
    required int profileAdjustment,
    required int taskAdjustment,
    required int finalRisk,
  }) {
    final lines = <String>[];

    lines.add('Baz skor: $baseRisk');
    lines.add('Davranis/trend etkisi: ${_signed(dynamicCoreRisk - baseRisk)}');
    lines.add('Nefes + anket kisisel etki: ${_signed(personalizedAdjustment)}');
    lines.add('Profil etki: ${_signed(profileAdjustment)}');
    lines.add('Gorev performans etki: ${_signed(taskAdjustment)}');
    lines.add('Sonuc risk skoru: $finalRisk');

    return lines;
  }

  int calculatePersonalizedRiskAdjustment({
    required List<SurveyRecord> surveyRecords,
    required List<SurveyRecord> breathRecords,
    required Map<String, dynamic>? latestContext,
    required List<SensorUsageEvent> sensorEvents,
  }) {
    var adjustment = 0;

    adjustment += _breathRiskAdjustmentFromRecords(breathRecords);
    adjustment += _surveyDependencyAdjustment(
      surveyRecords: surveyRecords,
      latestContext: latestContext,
    );
    adjustment += _sensorPressureAdjustment(sensorEvents);

    return adjustment.clamp(-20, 25);
  }

  String chooseTaskDifficulty(int riskScore) {
    if (riskScore >= 70) {
      return 'easy';
    }
    if (riskScore >= 40) {
      return 'medium';
    }
    return 'hard';
  }

  List<String> generateAdaptiveTasks({
    required int riskScore,
    required Map<String, double> taskSuccessRates,
    bool isFirstProfile = false,
    int count = 3,
    List<String> riskyTriggers = const <String>[],
    List<String> riskyHours = const <String>[],
    int recentSmokingCount = 0,
  }) {
    if (isFirstProfile) {
      if (riskScore >= 70) {
        return const ['Ilk sigaranizi 10 dakika geciktirin.'];
      }
      if (riskScore >= 40) {
        return const ['Ilk sigaranizi 20 dakika geciktirin.'];
      }
      return const ['Ilk sigaranizi 45 dakika geciktirin.'];
    }

    final difficulty = chooseTaskDifficulty(riskScore);
    final pool = difficulty == 'easy'
        ? _easyTasks
        : difficulty == 'medium'
        ? _mediumTasks
        : _hardTasks;

    final weighted = pool.map((task) {
      final rate = taskSuccessRates[task] ?? 0.5;
      final weight = (0.4 + rate).clamp(0.2, 1.6);
      return MapEntry(task, weight.toDouble());
    }).toList();

    final selected = <String>{};
    final contextualTask = _selectContextualTask(
      difficulty: difficulty,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      recentSmokingCount: recentSmokingCount,
    );
    if (contextualTask != null && weighted.any((item) => item.key == contextualTask)) {
      selected.add(contextualTask);
    }

    while (selected.length < min(count, weighted.length)) {
      final totalWeight = weighted.fold<double>(
        0,
        (sum, item) => sum + item.value,
      );
      final roll = _random.nextDouble() * totalWeight;
      var running = 0.0;
      for (final item in weighted) {
        running += item.value;
        if (roll <= running) {
          selected.add(item.key);
          break;
        }
      }
    }
    return selected.toList();
  }

  /// Chooses one task that directly addresses the strongest observed habit
  /// signal. The returned values are existing canonical task texts, so the
  /// normal AppTexts localization path remains responsible for all languages.
  String? _selectContextualTask({
    required String difficulty,
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required int recentSmokingCount,
  }) {
    final hasRepeatedRiskWindow = riskyHours.isNotEmpty;
    final hasTriggerSignal = riskyTriggers.isNotEmpty;
    if (!hasRepeatedRiskWindow && !hasTriggerSignal && recentSmokingCount < 2) {
      return null;
    }

    if (difficulty == 'easy') {
      return hasTriggerSignal
          ? 'Kriz anini not et'
          : '2 dakikalik nefes egzersizi yap';
    }
    if (difficulty == 'medium') {
      return hasRepeatedRiskWindow
          ? 'Riskli saatte seker sakiz kullan'
          : '30 dakika sigarasiz kal';
    }
    return recentSmokingCount >= 7
        ? 'Aksam saatinde destek kisisiyle iletisim kur'
        : '60 dakika sigarasiz kal';
  }

  /// Bounded risk adjustment from the most recent cough test result. No
  /// records means no penalty — the weekly survey already gates on having
  /// taken one this week (see WeeklySurveyPage), so missing data here is
  /// never possible for someone actively using the app, and double-
  /// penalizing "no test yet" the way [calculateProfileRiskAdjustment]'s
  /// `hasBreathTests` flag does would just stack two warnings for the same
  /// gap. A 'normal' result gets a small confidence discount, mirroring how
  /// clean weeks nudge other adjustments (steps, barrier success) downward.
  int calculateCoughRiskAdjustment({
    required List<CoughTestRecord> recentRecords,
  }) {
    if (recentRecords.isEmpty) return 0;
    switch (recentRecords.last.severityLevel) {
      case 'severe':
        return 8;
      case 'moderate':
        return 4;
      case 'mild':
        return 1;
      default:
        return -2;
    }
  }

  /// Bounded risk adjustment from how many snore-likely probes the
  /// (opt-in) overnight Snoring Test recorded recently — the first time
  /// this signal feeds into risk scoring rather than only surfacing as a
  /// Settings-screen counter.
  int calculateSnoringRiskAdjustment({required int recentSnoreLikelyCount}) {
    if (recentSnoreLikelyCount <= 0) return 0;
    if (recentSnoreLikelyCount >= 10) return 6;
    if (recentSnoreLikelyCount >= 4) return 3;
    return 1;
  }

  static const List<int> _coughAdvisoryTierOrder = [0, 1, 2, 3, 4];
  static const List<String> _coughAdvisoryTierNames = [
    'normal',
    'mild',
    'moderate',
    'severe',
    'urgent',
  ];

  /// Widens a single cough test's severity into a personalized advisory
  /// tier — not a diagnosis (this app never gives one, see CLAUDE.md), just
  /// a stronger or softer nudge toward seeing a doctor based on context the
  /// test alone can't see: an existing chronic respiratory/heart condition
  /// makes the same cough count more worth mentioning, and coughs that keep
  /// coming back across tests read differently than a one-off.
  ///
  /// [latestSeverityLevel] is the baseline tier. It's bumped up one step
  /// (never down — a chronic condition never makes a result look better)
  /// when the user has self-reported COPD or asthma and the baseline is
  /// already mild or worse: those two respiratory conditions are the ones
  /// where a new/worsening cough is specifically the thing to watch for,
  /// unlike e.g. hypertension. [recentTestCountLast14Days] moderate-or-worse
  /// results is a persistence signal independent of any single test's
  /// severity — three or more results at moderate+ in two weeks escalates
  /// straight to 'urgent' regardless of today's own severity, since a
  /// pattern across tests is the thing a single reading can never show.
  String resolveCoughAdvisoryTier({
    required String latestSeverityLevel,
    required List<String> healthConditions,
    required int recentModerateOrWorseCountLast14Days,
  }) {
    var tierIndex = _coughAdvisoryTierNames.indexOf(latestSeverityLevel);
    if (tierIndex < 0) {
      tierIndex = 0;
    }

    final hasRespiratoryCondition =
        healthConditions.contains('KOAH') || healthConditions.contains('Astim');
    if (hasRespiratoryCondition && tierIndex >= 1) {
      tierIndex = min(tierIndex + 1, _coughAdvisoryTierOrder.length - 1);
    }

    if (recentModerateOrWorseCountLast14Days >= 3) {
      tierIndex = _coughAdvisoryTierOrder.length - 1;
    }

    return _coughAdvisoryTierNames[tierIndex];
  }

  static const List<String> _wheezeAdvisoryTierNames = [
    'none',
    'mild',
    'moderate',
    'severe',
  ];

  /// Widens a single test's acoustic wheeze finding into a personalized
  /// advisory tier — structurally the same idea as [resolveCoughAdvisoryTier]
  /// (chronic-condition bump, recurrence escalation), but with 4 tiers
  /// instead of 5: a single acoustic wheeze reading is a much less validated
  /// signal than a cough count, so this deliberately stops at 'severe'
  /// rather than adding an 'urgent' tier on top of it.
  String resolveWheezeAdvisoryTier({
    required String latestWheezeSeverityLevel,
    required List<String> healthConditions,
    required int recentModerateOrWorseCountLast14Days,
  }) {
    var tierIndex = _wheezeAdvisoryTierNames.indexOf(latestWheezeSeverityLevel);
    if (tierIndex < 0) {
      tierIndex = 0;
    }

    final hasRespiratoryCondition =
        healthConditions.contains('KOAH') || healthConditions.contains('Astim');
    if (hasRespiratoryCondition && tierIndex >= 1) {
      tierIndex = min(tierIndex + 1, _wheezeAdvisoryTierNames.length - 1);
    }

    if (recentModerateOrWorseCountLast14Days >= 3) {
      tierIndex = _wheezeAdvisoryTierNames.length - 1;
    }

    return _wheezeAdvisoryTierNames[tierIndex];
  }

  static const List<String> _snoringAdvisoryTierNames = [
    'normal',
    'mild',
    'moderate',
    'severe',
  ];

  /// Converts one night's snore-likely probe count into a non-diagnostic
  /// advisory tier for the morning summary.
  String resolveSnoringAdvisoryTier({
    required int snoreCount,
    required List<String> healthConditions,
  }) {
    var tierIndex = 0;
    if (snoreCount >= 6) {
      tierIndex = 3;
    } else if (snoreCount >= 3) {
      tierIndex = 2;
    } else if (snoreCount >= 1) {
      tierIndex = 1;
    }

    final hasRespiratoryCondition =
        healthConditions.contains('KOAH') || healthConditions.contains('Astim');
    if (hasRespiratoryCondition && tierIndex >= 1) {
      tierIndex = min(tierIndex + 1, _snoringAdvisoryTierNames.length - 1);
    }
    return _snoringAdvisoryTierNames[tierIndex];
  }

  int calculateProfileRiskAdjustment({
    required String? profession,
    required String? sleepTime,
    required String? wakeTime,
    required List<String> healthConditions,
    required String packsPerDay,
    required String? consecutiveHabit,
    required String? consecutiveCount,
    required bool hasBreathTests,
  }) {
    var adjustment = 0;

    final normalizedProfession = _normalizeText(profession ?? '');
    if (normalizedProfession.contains('Saglik') ||
        normalizedProfession.contains('Isci') ||
        normalizedProfession.contains('Esnaf')) {
      adjustment += 2;
    }

    if (_hasShortSleepWindow(sleepTime: sleepTime, wakeTime: wakeTime)) {
      adjustment += 3;
    }

    adjustment += min(healthConditions.length, 4) * 2;
    adjustment += calculatePackRiskContribution(packsPerDay) ~/ 10;
    adjustment +=
        calculateConsecutiveSmokingScore(
          habit: consecutiveHabit,
          count: consecutiveCount,
        ) ~/
        5;

    if (!hasBreathTests) {
      adjustment += 6;
    }

    return adjustment;
  }

  AdaptivePlan buildAdaptivePlan180({
    required DateTime startDate,
    required int riskScore,
    required String breathTrend,
    required String smokingTrend,
    required List<String> riskyTriggers,
  }) {
    final elapsedDays = max(1, DateTime.now().difference(startDate).inDays + 1);
    final elapsedWeeks = max(1, ((elapsedDays - 1) ~/ 7) + 1);
    final daysRemaining = max(0, 180 - elapsedDays);
    final weeklyRiskTarget = max(
      5,
      (riskScore - elapsedWeeks * 2).clamp(5, 95),
    );
    final cadenceLevel = elapsedDays >= 120
        ? 'week'
        : elapsedDays >= 60
        ? 'two_days'
        : 'one_day';

    final focus = <String>[
      if (riskyTriggers.isNotEmpty) 'Tetikleyici yonetimi',
      if (breathTrend != 'Improving') 'Nefes performansi',
      if (smokingTrend != 'Decreasing') 'Paket azaltma',
      if (riskyTriggers.isEmpty) 'Rutin koruma',
    ];

    return AdaptivePlan(
      generatedAt: DateTime.now(),
      targetDays: 180,
      currentWeek: elapsedWeeks,
      currentDay: elapsedDays,
      daysRemaining: daysRemaining,
      weeklyRiskTarget: weeklyRiskTarget,
      difficulty: chooseTaskDifficulty(riskScore),
      cadenceLevel: cadenceLevel,
      focusAreas: focus.take(3).toList(),
    );
  }

  String generateProgressiveCadenceTask180({
    required AdaptivePlan plan,
    required int recentSuccessCount,
    required int recentFailureCount,
  }) {
    final isStruggling = recentFailureCount > recentSuccessCount;

    if (plan.currentDay >= 120) {
      if (isStruggling) {
        return '2 gun sigarasiz kalma plani: kriz aninda 10 derin nefes + su uygulayin.';
      }
      return '1 hafta sigarasiz kalma hedefi: 7 gun boyunca tum gorevleri tamamlayin.';
    }

    if (plan.currentDay >= 60) {
      if (isStruggling) {
        return '1 gun sigarasiz kalma gorevi: ilk sigarayi en az 90 dakika erteleyin.';
      }
      return '2 gun sigarasiz kalma gorevi: 48 saat boyunca tetikleyicilerde sigarayi erteleyin.';
    }

    return '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.';
  }

  BehaviorDashboard buildDashboard({
    required int riskScore,
    required List<SurveyRecord> records,
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required List<String> todaysTasks,
    required List<String> coachCommands,
    required Map<String, double> commandSuccessScores,
    required Map<String, double> commandCategoryScores,
    required String commandMixMode,
    required int weeklySurveyRiskScore,
    required String weeklySurveyRiskLevel,
    required List<String> weeklyTopRiskDrivers,
    required List<String> riskExplanation,
    required Map<String, double> learnedWeights,
    required Map<String, dynamic> prediction,
    required AdaptivePlan plan,
    String breathTrendLast3 = 'stable',
    int breathTrendRiskAdjustment = 0,
  }) {
    DateTime? lastSurveyDate;
    DateTime? lastBreathDate;

    for (final record in records) {
      if ((record.type == 'initial' || record.type == 'weekly') &&
          (lastSurveyDate == null ||
              record.completedAt.isAfter(lastSurveyDate))) {
        lastSurveyDate = record.completedAt;
      }
      if (record.type == 'breath_test' &&
          (lastBreathDate == null ||
              record.completedAt.isAfter(lastBreathDate))) {
        lastBreathDate = record.completedAt;
      }
    }

    final breathTrend = calculateBreathTrendFromRecords(records);
    final smokingTrend = calculateSmokingTrendFromRecords(records);
    final consecutiveTrend = evaluateConsecutiveSmokingTrendFromRecords(
      records,
    );

    final progressSummary = _deriveProgressStatus(
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      riskTrend: consecutiveTrend == 'trendDeclining' ? 'Declining' : 'Stable',
    );

    return BehaviorDashboard(
      riskScore: riskScore,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      lastSurveyDate: lastSurveyDate,
      lastBreathDate: lastBreathDate,
      breathTrend: breathTrend,
      breathTrendLast3: breathTrendLast3,
      breathTrendRiskAdjustment: breathTrendRiskAdjustment,
      progressSummary: progressSummary,
      todaysTasks: todaysTasks,
      coachCommands: coachCommands,
      commandSuccessScores: commandSuccessScores,
      commandCategoryScores: commandCategoryScores,
      commandMixMode: commandMixMode,
      weeklySurveyRiskScore: weeklySurveyRiskScore,
      weeklySurveyRiskLevel: weeklySurveyRiskLevel,
      weeklyTopRiskDrivers: weeklyTopRiskDrivers,
      riskExplanation: riskExplanation,
      learnedWeights: learnedWeights,
      predictedRiskWindow: prediction['nextRiskWindow'] as String,
      predictionConfidence: prediction['confidence'] as int,
      predictedTrigger: prediction['nextRiskTrigger'] as String,
      plan: plan,
    );
  }

  String _dataConfidence({
    required int surveyCount,
    required int breathCount,
    required int taskCount,
  }) {
    final evidenceCount = surveyCount + breathCount + taskCount;
    if (surveyCount >= 3 && evidenceCount >= 8) return 'high';
    if (evidenceCount >= 3 || surveyCount >= 1) return 'medium';
    return 'low';
  }

  String _dataFreshness({
    required DateTime? latestEvidenceAt,
    DateTime? now,
  }) {
    if (latestEvidenceAt == null) return 'noData';
    final age = (now ?? DateTime.now()).difference(latestEvidenceAt);
    if (age.isNegative || age.inDays <= 7) return 'fresh';
    if (age.inDays <= 30) return 'aging';
    return 'stale';
  }

  String _recoveryMode({
    required String smokingTrend,
    required String riskTrend,
    required String progressStatus,
    required List<TaskHistory> taskHistory,
  }) {
    final recent = taskHistory.length > 5
        ? taskHistory.sublist(taskHistory.length - 5)
        : taskHistory;
    final recentFailureRate = recent.isEmpty
        ? 0.0
        : recent.where((item) => !item.completed).length / recent.length;
    if (smokingTrend == 'Increasing' ||
        riskTrend == 'Declining' ||
        recentFailureRate >= 0.6) {
      return 'relapseRisk';
    }
    if (progressStatus == 'Improving' &&
        (smokingTrend == 'Decreasing' || riskTrend == 'Improving')) {
      return 'recovery';
    }
    return 'steady';
  }

  List<String> _suggestionReasons({
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required String breathTrend,
    required String smokingTrend,
    required String riskTrend,
    required String recoveryMode,
  }) {
    final reasons = <String>[];
    if (riskyTriggers.isNotEmpty) reasons.add('trigger_risk');
    if (riskyHours.isNotEmpty) reasons.add('risky_hours');
    if (breathTrend == 'Declining') reasons.add('breath_decline');
    if (smokingTrend == 'Increasing') reasons.add('smoking_increase');
    if (riskTrend == 'Declining') reasons.add('risk_increase');
    if (recoveryMode == 'relapseRisk') reasons.add('relapse_recovery');
    if (reasons.isEmpty) reasons.add('maintenance');
    return reasons;
  }

  UserBehaviorProfile generateBehaviorProfile({
    required List<SurveyHistory> surveys,
    required List<BreathTestRecord> breathTests,
    required List<TaskHistory> taskHistory,
    List<SurveyRecord> surveyRecords = const [],
    String subscriptionType = 'free',
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool trialActive = false,
    bool premiumFeaturesEnabled = false,
  }) {
    final triggerScores = calculateTriggerScores(surveys);
    final riskyTriggers = _selectRiskyTriggers(triggerScores);
    final riskyHours = calculateRiskyHours(surveys);
    final taskRates = calculateTaskSuccessRates(taskHistory);
    final breathTrend = calculateBreathTrend(breathTests);
    final smokingTrend = calculateSmokingTrend(surveys);
    final riskTrend = calculateRiskTrend(surveys);
    final consecutiveSmokingTrend = surveyRecords.isNotEmpty
        ? _calculateConsecutiveSmokingTrendFromRecords(surveyRecords)
        : calculateConsecutiveSmokingTrend(surveys);
    final consecutiveSmokingStatus = surveyRecords.isNotEmpty
        ? _calculateConsecutiveSmokingStatusFromRecords(surveyRecords)
        : _calculateConsecutiveSmokingStatusFromSurveys(surveys);

    final orderedSurveys = [...surveys]
      ..sort((a, b) => a.surveyDate.compareTo(b.surveyDate));
    final latestSurvey = orderedSurveys.isEmpty ? null : orderedSurveys.last;
    final riskScore = latestSurvey == null
        ? 0
        : _effectiveRiskScore(latestSurvey);
    DateTime? latestEvidenceAt = latestSurvey?.surveyDate;
    for (final breath in breathTests) {
      if (latestEvidenceAt == null || breath.date.isAfter(latestEvidenceAt)) {
        latestEvidenceAt = breath.date;
      }
    }
    for (final task in taskHistory) {
      if (latestEvidenceAt == null || task.date.isAfter(latestEvidenceAt)) {
        latestEvidenceAt = task.date;
      }
    }
    final progressStatus = _deriveProgressStatus(
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      riskTrend: riskTrend,
    );
    final recoveryMode = _recoveryMode(
      smokingTrend: smokingTrend,
      riskTrend: riskTrend,
      progressStatus: progressStatus,
      taskHistory: taskHistory,
    );
    final suggestionReasons = _suggestionReasons(
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      riskTrend: riskTrend,
      recoveryMode: recoveryMode,
    );

    final successfulTasks = <String, Map<String, dynamic>>{};
    final failedTasks = <String, Map<String, dynamic>>{};
    for (final task in taskRates) {
      final title = task['taskTitle'] as String;
      if ((task['successRate'] as double) >= 0.5) {
        successfulTasks[title] = task;
      } else {
        failedTasks[title] = task;
      }
    }

    return UserBehaviorProfile(
      riskScore: riskScore,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      successfulTasks: successfulTasks,
      failedTasks: failedTasks,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      riskTrend: riskTrend,
      consecutiveSmokingTrend: consecutiveSmokingTrend,
      consecutiveSmokingStatus: consecutiveSmokingStatus,
      progressStatus: progressStatus,
      suggestedTasks: _generateSuggestedTasks(
        riskyTriggers: riskyTriggers,
        riskyHours: riskyHours,
        breathTrend: breathTrend,
        smokingTrend: smokingTrend,
        riskTrend: riskTrend,
        consecutiveSmokingTrend: consecutiveSmokingTrend,
        consecutiveSmokingStatus: consecutiveSmokingStatus,
      ),
      lastSurveyDate: latestSurvey?.surveyDate,
      subscriptionType: subscriptionType,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      trialActive: trialActive,
      premiumFeaturesEnabled: premiumFeaturesEnabled,
      dataConfidence: _dataConfidence(
        surveyCount: surveys.length,
        breathCount: breathTests.length,
        taskCount: taskHistory.length,
      ),
      dataFreshness: _dataFreshness(latestEvidenceAt: latestEvidenceAt),
      recoveryMode: recoveryMode,
      suggestionReasons: suggestionReasons,
    );
  }

  String calculateProgressStatus({
    required String smokingTrend,
    required String breathTrend,
    required String riskTrend,
  }) {
    return _deriveProgressStatus(
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      riskTrend: riskTrend,
    );
  }

  String _deriveProgressStatus({
    required String smokingTrend,
    required String breathTrend,
    required String riskTrend,
  }) {
    if (smokingTrend == 'Increasing' ||
        breathTrend == 'Declining' ||
        riskTrend == 'Declining') {
      return 'Declining';
    }
    if (smokingTrend == 'Decreasing' ||
        breathTrend == 'Improving' ||
        riskTrend == 'Improving') {
      return 'Improving';
    }
    return 'Stable';
  }

  List<String> _selectRiskyTriggers(Map<String, int> triggerScores) {
    if (triggerScores.isEmpty) {
      return const [];
    }
    final maxScore = triggerScores.values.reduce(max);
    if (maxScore <= 0) {
      return const [];
    }
    final risky =
        triggerScores.entries
            .where((entry) => entry.value == maxScore)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    return risky;
  }

  String _normalizeTrigger(String trigger) {
    final normalized = _normalizeText(trigger);
    for (final key in _baseTriggerScores.keys) {
      if (_normalizeText(key) == normalized) {
        return key;
      }
    }
    return trigger;
  }

  String _normalizeText(String value) => normalizeTurkishText(value);

  String? _groupHour(String? hardestHour) {
    if (hardestHour == null || hardestHour.isEmpty) {
      return null;
    }

    final parts = hardestHour.split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return _groupHalfHourToTwoHourWindow(hour, minute);
  }

  String _groupHalfHourToTwoHourWindow(int hour, int minute) {
    final normalizedHour = minute >= 30 ? (hour + 1) % 24 : hour;
    final startHour = (normalizedHour ~/ 2) * 2;
    final endHour = (startHour + 2) % 24;
    return '${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00';
  }

  String _calculateConsecutiveSmokingTrendFromRecords(
    List<SurveyRecord> records,
  ) {
    final relevantRecords = _extractRelevantSurveyRecords(records);
    if (relevantRecords.length < 2) {
      return 'noRecordYet';
    }

    final previous = relevantRecords[relevantRecords.length - 2];
    final current = relevantRecords.last;
    return evaluateConsecutiveSmokingTrend(
      previousHabit: previous.consecutiveSmokingHabit,
      previousCount: previous.consecutiveSmokingCount,
      currentHabit: current.consecutiveSmokingHabit,
      currentCount: current.consecutiveSmokingCount,
    );
  }

  String _calculateConsecutiveSmokingStatusFromRecords(
    List<SurveyRecord> records,
  ) {
    final relevantRecords = _extractRelevantSurveyRecords(records);
    if (relevantRecords.isEmpty) {
      return 'noRecordYet';
    }
    final current = relevantRecords.last;
    return evaluateConsecutiveSmokingStatus(
      habit: current.consecutiveSmokingHabit,
      count: current.consecutiveSmokingCount,
    );
  }

  String _calculateConsecutiveSmokingStatusFromSurveys(
    List<SurveyHistory> surveys,
  ) {
    if (surveys.isEmpty) {
      return 'noRecordYet';
    }
    return surveys.last.chainSmokingLevel;
  }

  List<String> _generateSuggestedTasks({
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required String breathTrend,
    required String smokingTrend,
    required String riskTrend,
    required String consecutiveSmokingTrend,
    required String consecutiveSmokingStatus,
  }) {
    final suggestions = <String>{
      if (riskTrend == 'Declining' || riskyTriggers.isNotEmpty)
        'Riskli tetikleyicileri 1 hafta boyunca not et',
      if (riskyHours.isNotEmpty) 'Riskli saatlerde alternatif bir rutin uygula',
      if (breathTrend == 'Declining') 'Nefes testini gunluk tekrarla',
      if (smokingTrend == 'Increasing')
        'Gunluk paket miktarini bir kademe azalt',
      if (consecutiveSmokingTrend == 'trendDeclining')
        'Arka arkaya sigara dongusunu erteleme ile kir',
      if (consecutiveSmokingStatus.contains('5+ adet') ||
          consecutiveSmokingStatus.contains('4 adet'))
        'Arka arkaya icme adedini bir basamak dusur',
      if (riskTrend == 'Improving') 'Kazandigin ilerlemeyi rutine sabitle',
    };

    if (suggestions.isEmpty) {
      suggestions.add('Mevcut rutini surdur ve haftalik veriyi takip et');
    }

    return suggestions.take(3).toList();
  }

  Map<String, dynamic> buildHomeSummary(UserBehaviorProfile profile) {
    return {
      'riskScore': profile.riskScore,
      'riskTrend': profile.riskTrend,
      'smokingTrend': profile.smokingTrend,
      'breathTrend': profile.breathTrend,
      'consecutiveSmokingTrend': profile.consecutiveSmokingTrend,
      'consecutiveSmokingStatus': profile.consecutiveSmokingStatus,
      'progressStatus': profile.progressStatus,
      'riskyTriggers': profile.riskyTriggers,
      'riskyHours': profile.riskyHours,
      'suggestedTasks': profile.suggestedTasks,
      'lastSurveyDate': profile.lastSurveyDate,
      'dataConfidence': profile.dataConfidence,
      'dataFreshness': profile.dataFreshness,
      'recoveryMode': profile.recoveryMode,
      'suggestionReasons': profile.suggestionReasons,
    };
  }

  List<SurveyRecord> _extractRelevantSurveyRecords(List<SurveyRecord> records) {
    return records
        .where((record) => record.type == 'initial' || record.type == 'weekly')
        .toList();
  }

  double _averageBreathValue(BreathTestRecord record) {
    return (record.exhaleSeconds + record.inhaleSeconds) / 2;
  }

  int _packLevel(String packsPerDay) => SurveyRecord.packLevel(packsPerDay);

  int calculateChainSmokingRiskContribution(String chainSmokingLevel) {
    switch (chainSmokingLevel) {
      case 'Hayır':
      case 'Hayir':
        return 0;
      case '2 adet':
        return 5;
      case '3 adet':
        return 10;
      case '4 adet':
        return 15;
      case '5+ adet':
        return 20;
      default:
        return 0;
    }
  }

  int _effectiveRiskScore(SurveyHistory survey) {
    final total =
        survey.riskScore +
        calculatePackRiskContribution(survey.packsPerDay) +
        calculateChainSmokingRiskContribution(survey.chainSmokingLevel);
    return total.clamp(0, 100);
  }

  int _breathRiskAdjustmentFromRecords(List<SurveyRecord> breathRecords) {
    if (breathRecords.isEmpty) {
      return 4;
    }

    final sorted = [...breathRecords]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final latest = sorted.last;
    final latestAverage =
        ((latest.exhaleTestSeconds + latest.inhaleTestSeconds) / 2).toDouble();

    var adjustment = 0;
    if (latestAverage <= 4) {
      adjustment += 10;
    } else if (latestAverage <= 7) {
      adjustment += 6;
    } else if (latestAverage <= 10) {
      adjustment += 2;
    } else if (latestAverage <= 14) {
      adjustment -= 2;
    } else {
      adjustment -= 5;
    }

    if (sorted.length >= 2) {
      final previous = sorted[sorted.length - 2];
      final previousAverage =
          ((previous.exhaleTestSeconds + previous.inhaleTestSeconds) / 2)
              .toDouble();
      final delta = latestAverage - previousAverage;
      if (delta >= 1.5) {
        adjustment -= 4;
      } else if (delta <= -1.5) {
        adjustment += 5;
      }
    }

    final recentAverages = sorted.reversed
        .take(5)
        .map(
          (item) => ((item.exhaleTestSeconds + item.inhaleTestSeconds) / 2)
              .toDouble(),
        )
        .toList();
    final variability = _stdDev(recentAverages);
    if (variability > 2.5) {
      adjustment += 4;
    } else if (variability > 1.5) {
      adjustment += 2;
    } else if (variability < 0.8 && recentAverages.length >= 3) {
      adjustment -= 2;
    }

    return adjustment;
  }

  int _surveyDependencyAdjustment({
    required List<SurveyRecord> surveyRecords,
    required Map<String, dynamic>? latestContext,
  }) {
    if (surveyRecords.isEmpty) {
      return 0;
    }

    final sorted = [...surveyRecords]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final latest = sorted.last;
    final previous = sorted.length > 1 ? sorted[sorted.length - 2] : null;

    var adjustment = 0;
    final packDelta =
        _packLevel(latest.packsPerDay) -
        (previous == null
            ? _packLevel(latest.packsPerDay)
            : _packLevel(previous.packsPerDay));
    if (packDelta > 0) {
      adjustment += min(packDelta * 4, 12);
    } else if (packDelta < 0) {
      adjustment -= min(packDelta.abs() * 3, 9);
    }

    final consecutiveScore = calculateConsecutiveSmokingScore(
      habit: latest.consecutiveSmokingHabit,
      count: latest.consecutiveSmokingCount,
    );
    adjustment += (consecutiveScore / 3).round();

    final stressRaw = latestContext?['stressLevel']?.toString() ?? '';
    final stress = _normalizeText(stressRaw).toLowerCase();
    if (stress.contains('yuksek') || stress.contains('kotu')) {
      adjustment += 6;
    } else if (stress.contains('orta')) {
      adjustment += 2;
    } else if (stress.contains('iyi') || stress.contains('dusuk')) {
      adjustment -= 2;
    }

    final firstCigaretteRange =
        latestContext?['firstCigaretteRange']?.toString() ?? '';
    final firstCigaretteMid = _rangeMidpoint(firstCigaretteRange);
    if (firstCigaretteMid != null) {
      if (firstCigaretteMid <= 5) {
        adjustment += 7;
      } else if (firstCigaretteMid <= 10) {
        adjustment += 5;
      } else if (firstCigaretteMid <= 30) {
        adjustment += 2;
      } else if (firstCigaretteMid >= 60) {
        adjustment -= 3;
      }
    }

    final smokeFreeRange = latestContext?['smokeFreeRange']?.toString() ?? '';
    final smokeFreeMid = _rangeMidpoint(smokeFreeRange);
    if (smokeFreeMid != null) {
      if (smokeFreeMid <= 15) {
        adjustment += 7;
      } else if (smokeFreeMid <= 30) {
        adjustment += 4;
      } else if (smokeFreeMid <= 60) {
        adjustment += 1;
      } else if (smokeFreeMid >= 120) {
        adjustment -= 4;
      }
    }

    return adjustment;
  }

  int _sensorPressureAdjustment(List<SensorUsageEvent> sensorEvents) {
    if (sensorEvents.isEmpty) {
      return 0;
    }

    final recent = sensorEvents.length > 12
        ? sensorEvents.sublist(sensorEvents.length - 12)
        : sensorEvents;
    final highPressureCount = recent
        .where(
          (event) =>
              event.screenUnlockCount >= 12 ||
              event.appUsageMinutes >= 40 ||
              event.activityState == 'driving' ||
              event.mealSoundLikelihood >= 0.65 ||
              event.ambientPeakDecibel >= 78,
        )
        .length;
    final ratio = highPressureCount / recent.length;
    if (ratio >= 0.6) {
      return 6;
    }
    if (ratio >= 0.35) {
      return 3;
    }
    return 0;
  }

  double _stdDev(List<double> values) {
    if (values.length < 2) {
      return 0;
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) => pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  int? _rangeMidpoint(String rawRange) {
    final value = rawRange.trim();
    if (value.isEmpty || value == 'unknown') {
      return null;
    }

    if (value.endsWith('+')) {
      final start = int.tryParse(value.substring(0, value.length - 1));
      return start == null ? null : start + 30;
    }

    final parts = value.split('-');
    if (parts.length != 2) {
      return null;
    }

    final low = int.tryParse(parts[0]);
    final high = int.tryParse(parts[1]);
    if (low == null || high == null) {
      return null;
    }
    return ((low + high) / 2).round();
  }

  bool _hasShortSleepWindow({
    required String? sleepTime,
    required String? wakeTime,
  }) {
    if (sleepTime == null || wakeTime == null) {
      return false;
    }

    final sleepParts = sleepTime.split(':');
    final wakeParts = wakeTime.split(':');
    if (sleepParts.length != 2 || wakeParts.length != 2) {
      return false;
    }

    final sleepHour = int.tryParse(sleepParts[0]);
    final sleepMinute = int.tryParse(sleepParts[1]);
    final wakeHour = int.tryParse(wakeParts[0]);
    final wakeMinute = int.tryParse(wakeParts[1]);
    if (sleepHour == null ||
        sleepMinute == null ||
        wakeHour == null ||
        wakeMinute == null) {
      return false;
    }

    final sleepTotal = sleepHour * 60 + sleepMinute;
    var wakeTotal = wakeHour * 60 + wakeMinute;
    if (wakeTotal <= sleepTotal) {
      wakeTotal += 24 * 60;
    }

    final duration = wakeTotal - sleepTotal;
    return duration < 6 * 60;
  }

  String _signed(int value) {
    if (value > 0) {
      return '+$value';
    }
    return '$value';
  }

  int _consumptionScore(int avgCigarettesPerDay) {
    if (avgCigarettesPerDay <= 0) {
      return 0;
    }
    if (avgCigarettesPerDay <= 5) {
      return 20;
    }
    if (avgCigarettesPerDay <= 10) {
      return 40;
    }
    if (avgCigarettesPerDay <= 20) {
      return 65;
    }
    return 85;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Reads a multi-select answer.
  ///
  /// Tolerates the old shape (a map of key → severity/day count) so records
  /// written before the survey rework still score: any non-zero entry counts
  /// as "reported". Without this, every survey already in the database would
  /// silently drop to zero withdrawal and zero triggers.
  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is Map) {
      return value.entries
          .where((entry) => _toInt(entry.value) > 0)
          .map((entry) => entry.key.toString())
          .toList(growable: false);
    }
    return const <String>[];
  }

  String _resolveRespiratoryState({
    required double burden,
    required int mmrcGrade,
    required int warningNight,
    required int warningSputumColor,
  }) {
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
}
