import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_test_engine.dart';
import 'package:no_smoke/models/breath_test_result.dart';

void main() {
  group('BreathTestEngine', () {
    final engine = BreathTestEngine();

    test('computes breath score with configured component weights', () {
      final score = engine.breathScore(
        holdRisk: 80,
        blowRisk: 60,
        stabilityRisk: 40,
        intensityRisk: 20,
      );

      expect(score, closeTo(59, 0.001));
    });

    test('computes final risk with survey behavior task breath weights', () {
      final finalRisk = engine.calculateFinalRisk(
        surveyRisk: 70,
        behaviorRisk: 60,
        taskPerformanceRisk: 50,
        breathScore: 40,
      );

      expect(finalRisk, 59);
    });

    test('applies trend bonus for 5 strictly improving tests', () {
      final base = DateTime(2026, 1, 1);
      final results = List.generate(5, (i) {
        return BreathTestResult(
          id: 'b_$i',
          createdAt: base.add(Duration(days: i)),
          holdDuration: 20,
          blowDuration: 6,
          blowIntensity: 0.6,
          blowStability: 0.6,
          holdRisk: 60,
          blowRisk: 60,
          intensityRisk: 40,
          stabilityRisk: 40,
          breathScore: 80 - (i * 5).toDouble(),
          riskContribution: 0,
        );
      });

      final trend = engine.analyzeTrend(results);
      expect(trend.riskAdjustment, -5);
      expect(trend.trendLast3, 'improving');
    });

    test('applies trend penalty for 7 strictly worsening tests', () {
      final base = DateTime(2026, 1, 1);
      final results = List.generate(7, (i) {
        return BreathTestResult(
          id: 'w_$i',
          createdAt: base.add(Duration(days: i)),
          holdDuration: 20,
          blowDuration: 6,
          blowIntensity: 0.6,
          blowStability: 0.6,
          holdRisk: 60,
          blowRisk: 60,
          intensityRisk: 40,
          stabilityRisk: 40,
          breathScore: 30 + (i * 4).toDouble(),
          riskContribution: 0,
        );
      });

      final trend = engine.analyzeTrend(results);
      expect(trend.riskAdjustment, 5);
      expect(trend.trendLast7, 'worsening');
    });
  });
}
