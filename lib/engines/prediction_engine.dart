import 'dart:math';

import '../models/sensor_usage_event.dart';

class PredictionEngine {
	Map<String, dynamic> predictNextRisk({
		required List<String> riskyHours,
		required List<String> riskyTriggers,
		required int riskScore,
		required List<SensorUsageEvent> sensorEvents,
	}) {
		final nextRiskWindow = riskyHours.isNotEmpty ? riskyHours.first : '20:00-22:00';
		var nextRiskTrigger = riskyTriggers.isNotEmpty ? riskyTriggers.first : 'Stres';

		if (sensorEvents.isNotEmpty) {
			final recent = sensorEvents.sublist(max(0, sensorEvents.length - 8));
			final recentMealLikelihood =
					recent.map((item) => item.mealSoundLikelihood).reduce((a, b) => a + b) /
					recent.length;
			if (recentMealLikelihood >= 0.65) {
				nextRiskTrigger = 'Meal context';
			}
		}

		var confidence = 45;
		confidence += min(riskyHours.length, 3) * 8;
		confidence += min(riskyTriggers.length, 3) * 7;
		confidence += (riskScore / 10).round();
		confidence += _sensorConfidenceBoost(sensorEvents);

		return {
			'nextRiskWindow': nextRiskWindow,
			'nextRiskTrigger': nextRiskTrigger,
			'dailyRiskScore': riskScore.clamp(0, 100),
			'weeklyRiskScore': (riskScore * 0.95).round().clamp(0, 100),
			'confidence': confidence.clamp(10, 99),
		};
	}

	int _sensorConfidenceBoost(List<SensorUsageEvent> events) {
		if (events.isEmpty) {
			return 0;
		}

		var boost = 0;
		final recent = events.length > 24 ? events.sublist(events.length - 24) : events;
		for (final event in recent) {
			if (event.screenUnlockCount >= 10) {
				boost += 1;
			}
			if (event.appUsageMinutes >= 30) {
				boost += 1;
			}
			if (event.accelerometerMagnitude >= 1.7 || event.gyroscopeMagnitude >= 0.9) {
				boost += 1;
			}
			if (event.idleMinutes >= 45) {
				boost += 1;
			}
		}

		return boost.clamp(0, 14);
	}
}
