import 'dart:math';

import '../core/mentor_command_codes.dart';
import '../core/text_utils.dart';
import '../models/survey_record.dart';

class MentorEngine {
  final Random _random = Random();

  List<String> prioritizeTasks({
    required List<String> tasks,
    required int riskScore,
    String? primaryTrigger,
    String? predictedWindow,
  }) {
    if (tasks.isEmpty) {
      return const [];
    }

    final scored = tasks.map((task) {
      var score = 0;

      final normalizedTask = task.toLowerCase();
      final normalizedTrigger = (primaryTrigger ?? '').toLowerCase();

      if (riskScore >= 75 && normalizedTask.contains('ertele')) {
        score += 3;
      }
      if (riskScore >= 60 && normalizedTask.contains('nefes')) {
        score += 2;
      }
      if (normalizedTrigger.isNotEmpty &&
          normalizedTask.contains(normalizedTrigger)) {
        score += 2;
      }
      if ((predictedWindow ?? '').isNotEmpty &&
          normalizedTask.contains('riskli saat')) {
        score += 1;
      }

      return MapEntry(task, score);
    }).toList();

    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) {
        return byScore;
      }
      return a.key.compareTo(b.key);
    });

    return scored.map((entry) => entry.key).toList();
  }

  List<String> buildCoachingHints({
    required int riskScore,
    required String? predictedWindow,
    required String? predictedTrigger,
  }) {
    final hints = <String>[];

    if (riskScore >= 80) {
      hints.add(MentorCommandCodes.hintHighRisk);
    } else if (riskScore >= 60) {
      hints.add(MentorCommandCodes.hintMedRisk);
    } else {
      hints.add(MentorCommandCodes.hintLowRisk);
    }

    if ((predictedWindow ?? '').isNotEmpty) {
      hints.add('${MentorCommandCodes.hintWindowPrefix}:${predictedWindow!}');
    }

    if ((predictedTrigger ?? '').isNotEmpty) {
      hints.add('${MentorCommandCodes.hintTriggerPrefix}:${predictedTrigger!}');
    }

    return hints.take(3).toList();
  }

  List<String> buildActionCommands({
    required int riskScore,
    required String breathTrend,
    required String smokingTrend,
    required String consecutiveTrend,
    required int weeklyRiskTarget,
    required List<String> riskyHours,
    required String? predictedWindow,
    required String? predictedTrigger,
    required Map<String, dynamic>? weeklyPayload,
  }) {
    final commands = <String>[];
    final dayPart = _resolveDayPart(
      predictedWindow: predictedWindow,
      riskyHours: riskyHours,
    );
    final riskBand = _riskBand(riskScore);
    final burdenLevel = _commandBurdenLevel(weeklyPayload);

    commands.add(_progressiveReductionCommand(riskScore));
    commands.addAll(_riskDaypartCommands(riskBand: riskBand, dayPart: dayPart));
    commands.addAll(_weeklyPersonalizedCommands(weeklyPayload));

    if (breathTrend == 'Declining') {
      commands.add(MentorCommandCodes.breathDeclining);
    } else if (breathTrend == 'Improving') {
      commands.add(MentorCommandCodes.breathImproving);
    } else {
      commands.add(MentorCommandCodes.breathStable);
    }

    if (smokingTrend == 'Increasing' || consecutiveTrend == 'trendDeclining') {
      commands.add(MentorCommandCodes.trackReduceToday);
    } else {
      commands.add(MentorCommandCodes.trackCompleteThree);
    }

    if ((predictedWindow ?? '').isNotEmpty) {
      commands.add(
        '${MentorCommandCodes.prepWindowPrefix}:${predictedWindow!}',
      );
    }
    if ((predictedTrigger ?? '').isNotEmpty) {
      commands.add(
        '${MentorCommandCodes.triggerDelayPrefix}:${predictedTrigger!}',
      );
    }
    if (riskyHours.isNotEmpty) {
      commands.add(
        '${MentorCommandCodes.focusRiskHourPrefix}:${riskyHours.first}',
      );
    }
    if (weeklyRiskTarget > 0) {
      commands.add(
        '${MentorCommandCodes.weeklyTargetPrefix}:$weeklyRiskTarget',
      );
    }

    final unique = <String>[];
    for (final command in commands) {
      if (!unique.contains(command)) {
        unique.add(command);
      }
    }

    final selected = unique.take(4).toList();
    return _applyBurdenStyle(selected, burdenLevel);
  }

  List<String> buildDurationBarrierCommands({
    required int riskScore,
    required String? predictedWindow,
    required List<String> riskyHours,
    required int recentSuccessCount,
    required int recentFailureCount,
    required double barrierSuccessRate,
    required int recentBarrierSuccessCount,
    required int recentBarrierFailureCount,
    required double recentTaskCompletionRate,
    required String packsPerDay,
    required String? firstCigaretteRange,
    required String? smokeFreeRange,
    required String? stressLevel,
    required String? workplaceSmokingRule,
    required String barrierPreference,
    required String barrierFrequencyPreference,
    required bool barrierEnabled,
    required int durationBarrierHistoryCount,
  }) {
    if (!barrierEnabled) {
      return const [];
    }

    final dayPart = _resolveDayPart(
      predictedWindow: predictedWindow,
      riskyHours: riskyHours,
    );

    final nicotineLoad = _nicotineLoadScore(packsPerDay);
    final firstSmokeUrgency = _firstSmokeUrgencyScore(firstCigaretteRange);
    final smokeFreeCapacity = _smokeFreeCapacityScore(smokeFreeRange);
    final stressScore = _stressScore(stressLevel);
    final workplaceScore = _workplaceRuleScore(workplaceSmokingRule);

    var minMinutes =
        ((8 + (smokeFreeCapacity * 0.38)) +
                ((100 - riskScore) * 0.14) +
                (barrierSuccessRate * 14) +
                (recentTaskCompletionRate * 9) -
                (nicotineLoad * 2.0) -
                (firstSmokeUrgency * 1.9) -
                (stressScore * 2.4) +
                (workplaceScore * 0.8))
            .round();

    var dynamicSpan =
        (24 +
                (riskScore * 0.52) +
                (smokeFreeCapacity * 0.21) +
                (nicotineLoad * 1.5) +
                (stressScore * 2.0))
            .round();

    var count =
        (1.35 +
                (riskScore / 40) +
                ((1.0 - barrierSuccessRate.clamp(0.0, 1.0)) * 1.6) +
                ((1.0 - recentTaskCompletionRate.clamp(0.0, 1.0)) * 1.1) +
                (nicotineLoad / 6))
            .round();

    if (durationBarrierHistoryCount == 0) {
      count = 5;
    } else {
      final progressionTier = (durationBarrierHistoryCount / 2).floor().clamp(
        1,
        4,
      );
      final riskTier = riskScore >= 70
          ? 2
          : riskScore >= 50
          ? 1
          : 0;
      count = (count + riskTier + (progressionTier >= 3 ? 1 : 0)).clamp(1, 6);
      minMinutes += progressionTier * 4 + riskTier * 3;
      dynamicSpan += progressionTier * 6 + riskTier * 4;
    }

    final barrierScore = _dailyBarrierScore(
      barrierSuccessRate: barrierSuccessRate,
      recentTaskCompletionRate: recentTaskCompletionRate,
    );

    if (barrierScore >= 0.80) {
      minMinutes += 10;
      dynamicSpan += 18;
      count = (count - 1).clamp(1, 6);
    } else if (barrierScore < 0.50) {
      minMinutes -= 8;
      dynamicSpan -= 8;
      count = (count + 1).clamp(2, 6);
    }

    if (recentBarrierFailureCount >= 3) {
      minMinutes -= 10;
      dynamicSpan -= 6;
      count = (count + 1).clamp(2, 6);
    }
    if (recentBarrierSuccessCount >= 5) {
      minMinutes += 15;
      dynamicSpan += 20;
      count = (count - 1).clamp(1, 5);
    }

    if (recentFailureCount > recentSuccessCount) {
      count = (count + 1).clamp(2, 6);
    }

    if (barrierPreference == 'like') {
      minMinutes += 6;
      dynamicSpan += 10;
    } else if (barrierPreference == 'dislike') {
      count = (count - 1).clamp(1, 5);
      dynamicSpan -= 4;
    } else if (barrierPreference == 'off') {
      return const [];
    }

    if (barrierFrequencyPreference == 'az') {
      count = (count - 1).clamp(1, 5);
    } else if (barrierFrequencyPreference == 'cok') {
      count = (count + 1).clamp(2, 6);
    }

    final riskMinMax = _barrierMinuteRange(riskScore, dayPart);
    if (riskMinMax.$1 > minMinutes && barrierScore < 0.50) {
      minMinutes = riskMinMax.$1;
    }

    if (minMinutes < 8) {
      minMinutes = 8;
    }
    if (dynamicSpan < 15) {
      dynamicSpan = 15;
    }
    var maxMinutes = minMinutes + dynamicSpan;
    if (maxMinutes < riskMinMax.$1 + 10) {
      maxMinutes = riskMinMax.$1 + 10;
    }
    if (maxMinutes > 260) {
      maxMinutes = 260;
    }
    if (maxMinutes < minMinutes + 15) {
      maxMinutes = minMinutes + 15;
    }
    final minMax = (minMinutes, maxMinutes);

    final commands = <String>[];
    for (var i = 0; i < count; i++) {
      final minute = _pickUnpredictableMinute(
        minMinutes: minMax.$1,
        maxMinutes: minMax.$2,
        existing: commands,
      );
      commands.add('${MentorCommandCodes.adaptiveNoSmokePrefix}:$minute');
    }

    if ((predictedWindow ?? '').isNotEmpty) {
      commands.add(
        '${MentorCommandCodes.adaptiveNoSmokeWindowPrefix}:${minMax.$1}:${predictedWindow!}',
      );
    }

    return commands.take(5).toList();
  }

  double _dailyBarrierScore({
    required double barrierSuccessRate,
    required double recentTaskCompletionRate,
  }) {
    final normalizedBarrier = barrierSuccessRate.clamp(0.0, 1.0);
    final normalizedTask = recentTaskCompletionRate.clamp(0.0, 1.0);
    return (0.6 * normalizedBarrier) + (0.4 * normalizedTask);
  }

  // Delegates level-parsing to the canonical SurveyRecord.packLevel() —
  // this used to match pack option strings with .contains('1')/.contains('2')
  // etc, which is fragile (e.g. '1 paketten az' contains '1') and, worse,
  // never matched '6 paket'/'7+ paket' at all (no digit substring check
  // for them), silently giving the heaviest smokers the LOWEST nicotine
  // load score (3) instead of the highest.
  int _nicotineLoadScore(String packsPerDay) {
    final level = SurveyRecord.packLevel(packsPerDay);
    if (level >= 4) {
      return 9;
    }
    if (level == 3) {
      return 8;
    }
    if (level == 2) {
      return 6;
    }
    return 4;
  }

  int _firstSmokeUrgencyScore(String? firstCigaretteRange) {
    switch ((firstCigaretteRange ?? '').trim()) {
      case '0-5':
        return 8;
      case '5-10':
        return 7;
      case '10-30':
        return 5;
      case '30-60':
        return 3;
      case '60+':
        return 2;
      default:
        return 4;
    }
  }

  int _smokeFreeCapacityScore(String? smokeFreeRange) {
    switch ((smokeFreeRange ?? '').trim()) {
      case '0-15':
        return 15;
      case '15-30':
        return 28;
      case '30-60':
        return 45;
      case '60-120':
        return 80;
      case '120-240':
        return 140;
      case '240+':
        return 200;
      default:
        return 50;
    }
  }

  int _stressScore(String? stressLevel) {
    switch ((stressLevel ?? '').toLowerCase()) {
      case 'yüksek':
      case 'yuksek':
        return 8;
      case 'orta':
        return 5;
      case 'düşük':
      case 'dusuk':
        return 2;
      default:
        return 4;
    }
  }

  int _workplaceRuleScore(String? workplaceSmokingRule) {
    switch ((workplaceSmokingRule ?? '').toLowerCase()) {
      case 'hayır':
      case 'hayir':
        return 3;
      case 'sadece molalarda':
        return 1;
      case 'evet':
        return -1;
      default:
        return 0;
    }
  }

  (int, int) _barrierMinuteRange(int riskScore, String dayPart) {
    var minMinutes = riskScore >= 75
        ? 25
        : riskScore >= 55
        ? 18
        : 12;
    var maxMinutes = riskScore >= 75
        ? 120
        : riskScore >= 55
        ? 90
        : 60;

    if (dayPart == 'evening' || dayPart == 'night') {
      minMinutes += 8;
      maxMinutes += 20;
    }

    return (minMinutes, maxMinutes);
  }

  int _pickUnpredictableMinute({
    required int minMinutes,
    required int maxMinutes,
    required List<String> existing,
  }) {
    final used = existing
        .map((c) => RegExp(r'(\d+)').firstMatch(c)?.group(1))
        .whereType<String>()
        .map((x) => int.tryParse(x) ?? -1)
        .toSet();

    var attempt = 0;
    while (attempt < 20) {
      attempt += 1;
      final candidate =
          minMinutes + _random.nextInt((maxMinutes - minMinutes) + 1);
      if (!used.contains(candidate)) {
        return candidate;
      }
    }

    return minMinutes + _random.nextInt((maxMinutes - minMinutes) + 1);
  }

  String _commandBurdenLevel(Map<String, dynamic>? weeklyPayload) {
    final task =
        weeklyPayload?['task'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final level = (task['commandBurdenLevel']?.toString() ?? 'orta')
        .toLowerCase();
    if (level == 'az' || level == 'cok') {
      return level;
    }
    return 'orta';
  }

  // Tone is now carried as a suffix on the canonical ID rather than a word
  // substitution done here -- the engine no longer produces
  // language-specific text, so the actual soft/active wording change
  // happens in AppTexts._applyToneVariant at display time.
  List<String> _applyBurdenStyle(List<String> commands, String burdenLevel) {
    if (burdenLevel == 'cok') {
      return commands
          .map((command) => '$command${MentorCommandCodes.toneSoftSuffix}')
          .toList();
    }
    if (burdenLevel == 'az') {
      return commands
          .map((command) => '$command${MentorCommandCodes.toneActiveSuffix}')
          .toList();
    }
    return commands;
  }

  List<String> _weeklyPersonalizedCommands(
    Map<String, dynamic>? weeklyPayload,
  ) {
    if (weeklyPayload == null || weeklyPayload.isEmpty) {
      return const [];
    }

    final commands = <String>[];
    final trigger =
        weeklyPayload['triggerExposureDays'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final stressDays = _toInt(trigger['stress']);
    final coffeeDays = _toInt(trigger['coffee']);
    final alcoholDays = _toInt(trigger['alcohol']);
    final socialDays = _toInt(trigger['social']);

    if (stressDays >= 4) {
      commands.add(MentorCommandCodes.triggerStress);
    }
    if (coffeeDays >= 4) {
      commands.add(MentorCommandCodes.triggerCoffee);
    }
    if (alcoholDays >= 2) {
      commands.add(MentorCommandCodes.triggerAlcohol);
    }
    if (socialDays >= 3) {
      commands.add(MentorCommandCodes.triggerSocial);
    }

    final lapseCount = _toInt(weeklyPayload['lapseCount']);
    final cravingMax = _toInt(weeklyPayload['cravingMax']);
    final selfEfficacy = _toInt(weeklyPayload['selfEfficacy']);
    final motivation = _toInt(weeklyPayload['motivation']);

    if (lapseCount >= 2 || cravingMax >= 8) {
      commands.add(MentorCommandCodes.crisisProtocol);
    }
    if (selfEfficacy <= 4 || motivation <= 4) {
      commands.add(MentorCommandCodes.supportSingleGoal);
    }

    return commands;
  }

  String _riskBand(int riskScore) {
    if (riskScore >= 70) {
      return 'high';
    }
    if (riskScore >= 40) {
      return 'medium';
    }
    return 'low';
  }

  String _resolveDayPart({
    required String? predictedWindow,
    required List<String> riskyHours,
  }) {
    final source = (predictedWindow ?? '').trim().isNotEmpty
        ? predictedWindow!.split('-').first.trim()
        : (riskyHours.isNotEmpty ? riskyHours.first : '');

    final fromWindow = _parseHourFromText(source);
    final hour = fromWindow ?? DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return 'morning';
    }
    if (hour >= 11 && hour < 17) {
      return 'day';
    }
    if (hour >= 17 && hour < 22) {
      return 'evening';
    }
    return 'night';
  }

  int? _parseHourFromText(String value) {
    final match = RegExp(r'(\d{1,2}):\d{2}').firstMatch(value);
    if (match == null) {
      return null;
    }
    final parsed = int.tryParse(match.group(1) ?? '');
    if (parsed == null || parsed < 0 || parsed > 23) {
      return null;
    }
    return parsed;
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

  String _progressiveReductionCommand(int riskScore) {
    if (riskScore >= 75) {
      return MentorCommandCodes.reductionTier75;
    }
    if (riskScore >= 60) {
      return MentorCommandCodes.reductionTier60;
    }
    if (riskScore >= 40) {
      return MentorCommandCodes.reductionTier40;
    }
    return MentorCommandCodes.reductionTierBase;
  }

  // riskBand/dayPart feed directly into the canonical ID now (via
  // MentorCommandCodes.riskDaypartId) -- their string values are no
  // longer just labels, AppTexts.localizeCanonicalTextForCode parses
  // them back out of the ID, so _riskBand/_resolveDayPart's return
  // values must stay 'high'/'medium'/'low' and
  // 'morning'/'day'/'evening'/'night'.
  List<String> _riskDaypartCommands({
    required String riskBand,
    required String dayPart,
  }) {
    return [
      MentorCommandCodes.riskDaypartId(
        band: riskBand,
        dayPart: dayPart,
        index: 0,
      ),
      MentorCommandCodes.riskDaypartId(
        band: riskBand,
        dayPart: dayPart,
        index: 1,
      ),
    ];
  }

  Map<String, dynamic> optimizeActionCommands({
    required List<String> commands,
    required List<dynamic> taskHistory,
    required Map<String, double> previousScores,
  }) {
    if (commands.isEmpty) {
      return {
        'commands': const <String>[],
        'scores': <String, double>{},
        'categoryScores': <String, double>{},
      };
    }

    final globalSuccessRate = _globalSuccessRate(taskHistory);
    final scores = <String, double>{};

    for (final command in commands) {
      final prior = previousScores[command] ?? 0.50;
      final evidence = _commandEvidenceScore(command, taskHistory);

      double nextScore;
      if (evidence == null) {
        nextScore = (prior * 0.85) + (globalSuccessRate * 0.15);
      } else {
        nextScore = (prior * 0.60) + (evidence * 0.40);
      }

      scores[command] = nextScore.clamp(0.05, 0.95);
    }

    final ordered = [...commands]
      ..sort((a, b) {
        final byScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
        if (byScore != 0) {
          return byScore;
        }
        return a.compareTo(b);
      });
    final categoryScores = _deriveCategoryScores(ordered, scores);

    return {
      'commands': ordered,
      'scores': scores,
      'categoryScores': categoryScores,
    };
  }

  List<String> rebalanceCommandMix({
    required List<String> orderedCommands,
    required Map<String, double> commandScores,
    required Map<String, double> categoryScores,
    required String mode,
    int maxCount = 4,
  }) {
    if (orderedCommands.isEmpty) {
      return const <String>[];
    }

    final buckets = <String, List<String>>{};
    for (final command in orderedCommands) {
      final category = _categoryForCommand(command);
      buckets.putIfAbsent(category, () => <String>[]).add(command);
    }

    for (final entry in buckets.entries) {
      entry.value.sort(
        (a, b) => (commandScores[b] ?? 0).compareTo(commandScores[a] ?? 0),
      );
    }

    final sortedCategories = buckets.keys.toList()
      ..sort((a, b) {
        final sa = categoryScores[a] ?? 0.5;
        final sb = categoryScores[b] ?? 0.5;
        return sb.compareTo(sa);
      });

    final weakestCategories = [...sortedCategories]
      ..sort((a, b) {
        final sa = categoryScores[a] ?? 0.5;
        final sb = categoryScores[b] ?? 0.5;
        return sa.compareTo(sb);
      });

    final maxItems = maxCount < orderedCommands.length
        ? maxCount
        : orderedCommands.length;
    final priorityCategories = _modePriorityCategories(
      mode: mode,
      sortedCategories: sortedCategories,
      weakestCategories: weakestCategories,
    );
    final topCategory = priorityCategories.first;
    final weakestCategory = weakestCategories.first;
    final selected = <String>[];

    int pullFromCategory(String category, int count) {
      var added = 0;
      final list = buckets[category] ?? const <String>[];
      for (final command in list) {
        if (selected.contains(command)) {
          continue;
        }
        selected.add(command);
        added += 1;
        if (added >= count || selected.length >= maxItems) {
          break;
        }
      }
      return added;
    }

    final topQuota = mode == 'aggressive'
        ? (maxItems >= 4 ? 3 : 2)
        : mode == 'protective'
        ? 1
        : (maxItems >= 4 ? 2 : 1);
    pullFromCategory(topCategory, topQuota);

    if (mode != 'aggressive' &&
        weakestCategory != topCategory &&
        selected.length < maxItems) {
      pullFromCategory(weakestCategory, 1);
    }

    while (selected.length < maxItems) {
      var progressed = false;
      for (final category in priorityCategories) {
        final added = pullFromCategory(category, 1);
        if (added > 0) {
          progressed = true;
        }
        if (selected.length >= maxItems) {
          break;
        }
      }
      if (!progressed) {
        break;
      }
    }

    if (selected.length < maxItems) {
      for (final command in orderedCommands) {
        if (selected.contains(command)) {
          continue;
        }
        selected.add(command);
        if (selected.length >= maxItems) {
          break;
        }
      }
    }

    return selected;
  }

  List<String> _modePriorityCategories({
    required String mode,
    required List<String> sortedCategories,
    required List<String> weakestCategories,
  }) {
    if (sortedCategories.isEmpty) {
      return const <String>[];
    }

    if (mode == 'aggressive') {
      final first = <String>[];
      for (final support in const ['trigger', 'breath', 'delay']) {
        if (sortedCategories.contains(support)) {
          first.add(support);
        }
      }
      for (final category in sortedCategories) {
        if (!first.contains(category)) {
          first.add(category);
        }
      }
      return first;
    }

    if (mode == 'protective') {
      final first = <String>[];
      for (final stable in const ['routine', 'delay', 'reduction']) {
        if (sortedCategories.contains(stable)) {
          first.add(stable);
        }
      }
      for (final category in sortedCategories) {
        if (!first.contains(category)) {
          first.add(category);
        }
      }
      return first;
    }

    final mixed = <String>[];
    if (sortedCategories.isNotEmpty) {
      mixed.add(sortedCategories.first);
    }
    if (weakestCategories.isNotEmpty &&
        !mixed.contains(weakestCategories.first)) {
      mixed.add(weakestCategories.first);
    }
    for (final category in sortedCategories) {
      if (!mixed.contains(category)) {
        mixed.add(category);
      }
    }
    return mixed;
  }

  Map<String, double> _deriveCategoryScores(
    List<String> orderedCommands,
    Map<String, double> commandScores,
  ) {
    final grouped = <String, List<double>>{};
    for (final command in orderedCommands) {
      final category = _categoryForCommand(command);
      grouped
          .putIfAbsent(category, () => <double>[])
          .add(commandScores[command] ?? 0.5);
    }

    final result = <String, double>{};
    for (final entry in grouped.entries) {
      final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
      result[entry.key] = average;
    }
    return result;
  }

  // Canonical IDs carry their category in a prefix now, so this no longer
  // does word-matching on translated text -- that would break for every
  // non-Turkish user. Commands already persisted before this refactor
  // (DB-stored task titles, previousScores keys) are still raw Turkish
  // sentences, so those still go through the old contains()-based
  // classifier via _legacyCategoryForCommand.
  String _categoryForCommand(String command) {
    final id = _stripToneSuffix(command);
    if (_looksLikeCanonicalId(id)) {
      return _canonicalCategoryForId(id);
    }
    return _legacyCategoryForCommand(id) ?? 'routine';
  }

  String _stripToneSuffix(String command) {
    if (command.endsWith(MentorCommandCodes.toneSoftSuffix)) {
      return command.substring(
        0,
        command.length - MentorCommandCodes.toneSoftSuffix.length,
      );
    }
    if (command.endsWith(MentorCommandCodes.toneActiveSuffix)) {
      return command.substring(
        0,
        command.length - MentorCommandCodes.toneActiveSuffix.length,
      );
    }
    return command;
  }

  bool _looksLikeCanonicalId(String value) {
    final prefix = value.split(':').first;
    return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(prefix);
  }

  // Mirrors the pre-refactor contains()-based classification, applied to
  // the ORIGINAL Turkish sentence each ID replaced -- so a command that
  // used to fall into 'delay'/'breath'/'trigger'/'reduction' keeps landing
  // in the same bucket, just keyed by ID instead of by scanning text.
  // Verified by mechanically running the old classifier against every
  // original string rather than judged by eye (several entries are
  // non-obvious, e.g. TRIGGER_STRESS -> 'breath' because its Turkish
  // sentence mentions "nefes" before "stres", and the old code checks
  // 'nefes' first).
  static const Map<String, String> _canonicalCategoryById = {
    MentorCommandCodes.reductionTier75: 'delay',
    MentorCommandCodes.reductionTier60: 'reduction',
    MentorCommandCodes.reductionTier40: 'reduction',
    MentorCommandCodes.reductionTierBase: 'reduction',
    MentorCommandCodes.breathDeclining: 'breath',
    MentorCommandCodes.breathImproving: 'breath',
    MentorCommandCodes.breathStable: 'breath',
    MentorCommandCodes.trackReduceToday: 'routine',
    MentorCommandCodes.trackCompleteThree: 'routine',
    MentorCommandCodes.triggerStress: 'breath',
    MentorCommandCodes.triggerCoffee: 'trigger',
    MentorCommandCodes.triggerAlcohol: 'trigger',
    MentorCommandCodes.triggerSocial: 'trigger',
    MentorCommandCodes.crisisProtocol: 'delay',
    MentorCommandCodes.supportSingleGoal: 'reduction',
    'RISKDAYPART_HIGH_MORNING_0': 'delay',
    'RISKDAYPART_HIGH_MORNING_1': 'breath',
    'RISKDAYPART_HIGH_DAY_0': 'routine',
    'RISKDAYPART_HIGH_DAY_1': 'routine',
    'RISKDAYPART_HIGH_EVENING_0': 'delay',
    'RISKDAYPART_HIGH_EVENING_1': 'routine',
    'RISKDAYPART_HIGH_NIGHT_0': 'trigger',
    'RISKDAYPART_HIGH_NIGHT_1': 'breath',
    'RISKDAYPART_MEDIUM_MORNING_0': 'delay',
    'RISKDAYPART_MEDIUM_MORNING_1': 'breath',
    'RISKDAYPART_MEDIUM_DAY_0': 'routine',
    'RISKDAYPART_MEDIUM_DAY_1': 'routine',
    'RISKDAYPART_MEDIUM_EVENING_0': 'trigger',
    'RISKDAYPART_MEDIUM_EVENING_1': 'reduction',
    'RISKDAYPART_MEDIUM_NIGHT_0': 'routine',
    'RISKDAYPART_MEDIUM_NIGHT_1': 'routine',
    'RISKDAYPART_LOW_MORNING_0': 'delay',
    'RISKDAYPART_LOW_MORNING_1': 'breath',
    'RISKDAYPART_LOW_DAY_0': 'routine',
    'RISKDAYPART_LOW_DAY_1': 'routine',
    'RISKDAYPART_LOW_EVENING_0': 'delay',
    'RISKDAYPART_LOW_EVENING_1': 'routine',
    'RISKDAYPART_LOW_NIGHT_0': 'breath',
    'RISKDAYPART_LOW_NIGHT_1': 'routine',
  };

  String _canonicalCategoryForId(String id) {
    final direct = _canonicalCategoryById[id];
    if (direct != null) {
      return direct;
    }
    if (id.startsWith(MentorCommandCodes.triggerDelayPrefix)) {
      return 'delay';
    }
    if (id.startsWith(MentorCommandCodes.focusRiskHourPrefix)) {
      return 'trigger';
    }
    if (id.startsWith(MentorCommandCodes.weeklyTargetPrefix)) {
      return 'reduction';
    }
    // ADAPTIVE_NO_SMOKE*, PREP_WINDOW:*, HINT_* templates contained none
    // of 'nefes'/'ertele'/'tetikleyici'/'kriz'/'hedef' in their original
    // Turkish, so 'routine' matches prior behavior.
    return 'routine';
  }

  String? _legacyCategoryForCommand(String command) {
    final value = _normalize(command);
    if (value.contains('nefes')) {
      return 'breath';
    }
    if (value.contains('ertele')) {
      return 'delay';
    }
    if (value.contains('tetikleyici') ||
        value.contains('riskli saat') ||
        value.contains('kriz')) {
      return 'trigger';
    }
    if (value.contains('sigara adedini') ||
        value.contains('haftalik risk hedefi') ||
        value.contains('hedef')) {
      return 'reduction';
    }
    return 'routine';
  }

  double _globalSuccessRate(List<dynamic> taskHistory) {
    if (taskHistory.isEmpty) {
      return 0.50;
    }

    var success = 0;
    for (final item in taskHistory) {
      final completed = item.completed == true;
      if (completed) {
        success += 1;
      }
    }
    return success / taskHistory.length;
  }

  double? _commandEvidenceScore(String command, List<dynamic> taskHistory) {
    if (taskHistory.isEmpty) {
      return null;
    }

    final commandTokens = _tokens(command);
    if (commandTokens.isEmpty) {
      return null;
    }

    double weightedSuccess = 0;
    double totalWeight = 0;
    for (var i = 0; i < taskHistory.length; i++) {
      final item = taskHistory[i];
      final title = item.taskTitle?.toString() ?? '';
      final overlap = _overlapScore(commandTokens, _tokens(title));
      if (overlap <= 0) {
        continue;
      }

      final recencyWeight = 0.6 + (0.4 * ((i + 1) / taskHistory.length));
      final weight = overlap * recencyWeight;
      totalWeight += weight;
      if (item.completed == true) {
        weightedSuccess += weight;
      }
    }

    if (totalWeight <= 0) {
      return null;
    }

    return weightedSuccess / totalWeight;
  }

  Set<String> _tokens(String text) {
    final normalized = _normalize(text);
    final parts = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length >= 3)
        .toSet();
    return parts;
  }

  double _overlapScore(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }

    final intersection = a.where(b.contains).length;
    if (intersection == 0) {
      return 0;
    }

    final union = {...a, ...b}.length;
    return intersection / union;
  }

  String _normalize(String value) => normalizeTurkishText(value);
}
