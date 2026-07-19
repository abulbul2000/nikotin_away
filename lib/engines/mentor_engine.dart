import 'dart:math';

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
			if (normalizedTrigger.isNotEmpty && normalizedTask.contains(normalizedTrigger)) {
				score += 2;
			}
			if ((predictedWindow ?? '').isNotEmpty && normalizedTask.contains('riskli saat')) {
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
			hints.add('Yuksek risk donemindesiniz: ilk sigarayi mutlaka erteleyin.');
		} else if (riskScore >= 60) {
			hints.add('Orta-yuksek risk: tetikleyici aninda nefes + su rutini uygulayin.');
		} else {
			hints.add('Ritmi koruyun: bugun en az bir gorevi tamamlama hedefi koyun.');
		}

		if ((predictedWindow ?? '').isNotEmpty) {
			hints.add('En riskli pencere: ${predictedWindow!}. Bu saatten once hazirlik yapin.');
		}

		if ((predictedTrigger ?? '').isNotEmpty) {
			hints.add('Tahmini tetikleyici: ${predictedTrigger!}. Alternatif davranis belirleyin.');
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
		final dayPart = _resolveDayPart(predictedWindow: predictedWindow, riskyHours: riskyHours);
		final riskBand = _riskBand(riskScore);
		final burdenLevel = _commandBurdenLevel(weeklyPayload);

		commands.add('KADEMELI: ${_progressiveReductionCommand(riskScore)}');
		commands.addAll(_riskDaypartCommands(riskBand: riskBand, dayPart: dayPart));
		commands.addAll(_weeklyPersonalizedCommands(weeklyPayload));

		if (breathTrend == 'Declining') {
			commands.add('NEFES: Bugun 2 nefes testi yap, her testten sonra 2 dakika yavas nefes uygula.');
		} else if (breathTrend == 'Improving') {
			commands.add('NEFES: Kazanimi koru, risk saatinden once 1 nefes rutini tamamla.');
		} else {
			commands.add('NEFES: Kriz aninda 2 dakika nefes + 1 bardak su uygula.');
		}

		if (smokingTrend == 'Increasing' || consecutiveTrend == 'trendDeclining') {
			commands.add('TAKIP: Bugun toplam adedi dunun en az 2 altinda tamamla.');
		} else {
			commands.add('TAKIP: Bugun secilen gorevlerin en az 3 tanesini tamamlandi isaretle.');
		}

		if ((predictedWindow ?? '').isNotEmpty) {
			commands.add('HAZIRLIK: ${predictedWindow!} oncesinde su + sakiz + kisa yuruyus planini hazirla.');
		}
		if ((predictedTrigger ?? '').isNotEmpty) {
			commands.add('TETIKLEYICI: ${predictedTrigger!} aninda 3 dakika ertele, sonra yeniden karar ver.');
		}
		if (riskyHours.isNotEmpty) {
			commands.add('ODAK: En riskli saat ${riskyHours.first} icin bildirimleri acik tut.');
		}
		if (weeklyRiskTarget > 0) {
			commands.add('HEDEF: Haftalik risk hedefini $weeklyRiskTarget altina indir.');
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

		var minMinutes = (
			(8 + (smokeFreeCapacity * 0.38)) +
			((100 - riskScore) * 0.14) +
			(barrierSuccessRate * 14) +
			(recentTaskCompletionRate * 9) -
			(nicotineLoad * 2.0) -
			(firstSmokeUrgency * 1.9) -
			(stressScore * 2.4) +
			(workplaceScore * 0.8)
		).round();

		var dynamicSpan = (
			24 +
			(riskScore * 0.52) +
			(smokeFreeCapacity * 0.21) +
			(nicotineLoad * 1.5) +
			(stressScore * 2.0)
		).round();

		var count = (
			1.35 +
			(riskScore / 40) +
			((1.0 - barrierSuccessRate.clamp(0.0, 1.0)) * 1.6) +
			((1.0 - recentTaskCompletionRate.clamp(0.0, 1.0)) * 1.1) +
			(nicotineLoad / 6)
		).round();

		if (durationBarrierHistoryCount == 0) {
			count = 5;
		} else {
			final progressionTier = (durationBarrierHistoryCount / 2).floor().clamp(1, 4);
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
			commands.add('Sigara içmeme süresi: Sonraki $minute dakika sigara içmeyin.');
		}

		if ((predictedWindow ?? '').isNotEmpty) {
			commands.add(
				'Sigara içmeme süresi: ${predictedWindow!} penceresi öncesi en az ${minMax.$1} dakika sigara içmeyin.',
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

	int _nicotineLoadScore(String packsPerDay) {
		final value = packsPerDay.toLowerCase();
		if (value.contains('4') || value.contains('5') || value.contains('3+')) {
			return 9;
		}
		if (value.contains('3')) {
			return 8;
		}
		if (value.contains('2')) {
			return 6;
		}
		if (value.contains('1')) {
			return 4;
		}
		return 3;
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
			.map(
				(c) => RegExp(r'(\d+)').firstMatch(c)?.group(1),
			)
			.whereType<String>()
			.map((x) => int.tryParse(x) ?? -1)
			.toSet();

		var attempt = 0;
		while (attempt < 20) {
			attempt += 1;
			final candidate = minMinutes + _random.nextInt((maxMinutes - minMinutes) + 1);
			if (!used.contains(candidate)) {
				return candidate;
			}
		}

		return minMinutes + _random.nextInt((maxMinutes - minMinutes) + 1);
	}

	String _commandBurdenLevel(Map<String, dynamic>? weeklyPayload) {
		final task = weeklyPayload?['task'] as Map<String, dynamic>? ??
			const <String, dynamic>{};
		final level = (task['commandBurdenLevel']?.toString() ?? 'orta').toLowerCase();
		if (level == 'az' || level == 'cok') {
			return level;
		}
		return 'orta';
	}

	List<String> _applyBurdenStyle(List<String> commands, String burdenLevel) {
		if (burdenLevel == 'cok') {
			return commands.map(_softenCommandTone).toList();
		}
		if (burdenLevel == 'az') {
			return commands.map(_activateCommandTone).toList();
		}
		return commands;
	}

	String _softenCommandTone(String command) {
		var result = command
			.replaceAll('mutlaka ', '')
			.replaceAll('en az ', '')
			.replaceAll('tamamla', 'dene')
			.replaceAll('uygula', 'dene')
			.replaceAll('kapat', 'azalt');
		result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
		if (result.endsWith('!')) {
			result = '${result.substring(0, result.length - 1)}.';
		}
		return result;
	}

	String _activateCommandTone(String command) {
		var result = command.replaceAll('dene', 'uygula');
		if (!result.endsWith('!')) {
			if (result.endsWith('.')) {
				result = '${result.substring(0, result.length - 1)}!';
			} else {
				result = '$result!';
			}
		}
		return result;
	}

	List<String> _weeklyPersonalizedCommands(Map<String, dynamic>? weeklyPayload) {
		if (weeklyPayload == null || weeklyPayload.isEmpty) {
			return const [];
		}

		final commands = <String>[];
		final trigger = weeklyPayload['triggerExposureDays'] as Map<String, dynamic>? ??
			const <String, dynamic>{};
		final stressDays = _toInt(trigger['stress']);
		final coffeeDays = _toInt(trigger['coffee']);
		final alcoholDays = _toInt(trigger['alcohol']);
		final socialDays = _toInt(trigger['social']);

		if (stressDays >= 4) {
			commands.add('TETIKLEYICI-STRES: Stres aninda 90 saniye nefes + 1 bardak su, sonra yeniden karar ver.');
		}
		if (coffeeDays >= 4) {
			commands.add('TETIKLEYICI-KAHVE: Kahveyi 30 dakika geciktir, kahve ile sigarayi baglama.');
		}
		if (alcoholDays >= 2) {
			commands.add('TETIKLEYICI-ALKOL: Alkol gunlerinde ilk teklifte sigaraya hayir de, sakiz/su alternatifi kullan.');
		}
		if (socialDays >= 3) {
			commands.add('TETIKLEYICI-SOSYAL: Sosyal ortama girmeden once hedefini destek kisina mesajla.');
		}

		final lapseCount = _toInt(weeklyPayload['lapseCount']);
		final cravingMax = _toInt(weeklyPayload['cravingMax']);
		final selfEfficacy = _toInt(weeklyPayload['selfEfficacy']);
		final motivation = _toInt(weeklyPayload['motivation']);

		if (lapseCount >= 2 || cravingMax >= 8) {
			commands.add('KRIZ: Ilk istek dalgasinda 3 dakika ertele, ikinci dalgada 4D protokolunu uygula.');
		}
		if (selfEfficacy <= 4 || motivation <= 4) {
			commands.add('DESTEK: Bugun tek hedef sec ve tamamlayinca uygulamada isaretle.');
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
			return 'Bugun hedef: duneden en az 1 sigara az, ilk sigarayi 90 dakika ertele.';
		}
		if (riskScore >= 60) {
			return 'Bugun hedef: duneden en az 2 sigara az, her sigara oncesi 10 dakika bekle.';
		}
		if (riskScore >= 40) {
			return 'Bugun hedef: duneden en az 3 sigara az, oglen sonrasi 1 sigarayi atla.';
		}
		return 'Bugun hedef: mevcut azalmayi koru, riski saatlerde sigara yerine su + sakiz uygula.';
	}

	List<String> _riskDaypartCommands({
		required String riskBand,
		required String dayPart,
	}) {
		if (riskBand == 'high') {
			switch (dayPart) {
				case 'morning':
					return const [
						'SABAH: Ilk sigarayi 90 dakika ertele, once 1 bardak su ic.',
						'KRIZ: 4D protokolunu uygula (ertele-nefes-su-dikkat dagit).',
					];
				case 'day':
					return const [
						'OGLE: Yemek sonrasi 7 dakika yuruyus yap, sonra karar ver.',
						'TETIK: Kahve ile sigarayi ayir, kahveyi 30 dakika geciktir.',
					];
				case 'evening':
					return const [
						'AKSAM: Sosyal ortamda ilk teklife hayir de, 3 dakika ertele.',
						'DESTEK: Risk saatinden once destek kisina tek satir mesaj gonder.',
					];
				default:
					return const [
						'GECE: Bu saatten sonra sigara yok, acil kriz rutini uygula.',
						'GEVSEME: 3 dakika yavas nefes + su ile gunu kapat.',
					];
			}
		}

		if (riskBand == 'medium') {
			switch (dayPart) {
				case 'morning':
					return const [
						'SABAH: Ilk sigarayi 45 dakika ertele.',
						'RUTIN: Kahve oncesi 2 dakika nefes egzersizi yap.',
					];
				case 'day':
					return const [
						'OGLE: Her sigara oncesi 10 dakika bekle.',
						'ATLA: Bugun ogleden sonra 1 sigarayi atla.',
					];
				case 'evening':
					return const [
						'AKSAM: Riskli saatte sakiz/su alternatifi uygula.',
						'TAKIP: Gun sonu sayiminda hedefi kontrol et.',
					];
				default:
					return const [
						'GECE: Son sigaradan sonra su ic, tekrar sigara icme.',
						'PLAN: Yarin ilk sigara saatini simdiden 15 dakika geciktir.',
					];
			}
		}

		switch (dayPart) {
			case 'morning':
				return const [
					'SABAH: Ilk sigarayi en az 25 dakika ertele.',
					'KORU: Nefes kazancini korumak icin su + nefes rutini yap.',
				];
			case 'day':
				return const [
					'OGLE: Sadece planli saatlerde karar ver, otomatik yakma yok.',
					'KORU: Oglen sonrasi 1 sigara yerine 5 dakika yuruyus yap.',
				];
			case 'evening':
				return const [
					'AKSAM: Sosyal tetikleyicilerde 3 dakika erteleme uygula.',
					'KORU: Gun sonu notuna bugun ise yarayan yontemi yaz.',
				];
			default:
				return const [
					'GECE: Bu saatten sonra sigarayi kapat, kriz olursa nefes uygula.',
					'KORU: Yarin icin risk saatine tek bir onlem yaz.',
				];
		}
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
			grouped.putIfAbsent(category, () => <double>[]).add(
				commandScores[command] ?? 0.5,
			);
		}

		final result = <String, double>{};
		for (final entry in grouped.entries) {
			final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
			result[entry.key] = average;
		}
		return result;
	}

	String _categoryForCommand(String command) {
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

	String _normalize(String value) {
		return value
			.toLowerCase()
			.replaceAll('ı', 'i')
			.replaceAll('ğ', 'g')
			.replaceAll('ş', 's')
			.replaceAll('ö', 'o')
			.replaceAll('ü', 'u')
			.replaceAll('ç', 'c');
	}
}
