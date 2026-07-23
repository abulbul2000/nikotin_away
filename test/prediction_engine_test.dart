import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/prediction_engine.dart';
import 'package:no_smoke/models/sensor_usage_event.dart';

SensorUsageEvent _event({double mealSoundLikelihood = 0}) {
  return SensorUsageEvent(
    id: 'evt',
    createdAt: DateTime(2026, 1, 1),
    activityState: 'idle',
    accelerometerMagnitude: 0,
    gyroscopeMagnitude: 0,
    mealSoundLikelihood: mealSoundLikelihood,
    screenUnlockCount: 0,
    appUsageMinutes: 0,
    idleMinutes: 0,
    charging: false,
  );
}

void main() {
  group('PredictionEngine.predictNextRisk', () {
    test('falls back to the top risky trigger by default', () {
      final engine = PredictionEngine();
      final result = engine.predictNextRisk(
        riskyHours: const ['20:00-22:00'],
        riskyTriggers: const ['Kahve'],
        riskScore: 50,
        sensorEvents: const [],
      );

      expect(result['nextRiskTrigger'], 'Kahve');
    });

    test('overrides the trigger with meal context when recent sensor '
        'events show a high meal-sound likelihood', () {
      final engine = PredictionEngine();
      final sensorEvents = List.generate(
        8,
        (_) => _event(mealSoundLikelihood: 0.8),
      );

      final result = engine.predictNextRisk(
        riskyHours: const ['20:00-22:00'],
        riskyTriggers: const ['Kahve'],
        riskScore: 50,
        sensorEvents: sensorEvents,
      );

      expect(result['nextRiskTrigger'], 'Meal context');
    });
  });
}
