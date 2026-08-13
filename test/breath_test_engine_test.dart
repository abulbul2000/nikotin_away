import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
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

  group('buildResult with spirometry', () {
    final engine = BreathTestEngine();

    const spirometry = SpirometryEstimate(
      fev1EnergyIntegral: 0.18,
      fvcEnergyIntegral: 0.2,
      fev1FvcRatioPercent: 90,
      peakFlowIndex: 75,
      peakFlowAtMs: 200,
      curve: [],
    );

    BreathTestResult build({SpirometryEstimate? spirometry}) {
      return engine.buildResult(
        id: 'b',
        createdAt: DateTime(2026, 1, 1),
        holdDuration: 20,
        blowDuration: 6,
        blowIntensity: 0.6,
        blowStability: 0.6,
        spirometry: spirometry,
      );
    }

    test('populates spirometry fields when an estimate is passed', () {
      final result = build(spirometry: spirometry);

      expect(result.fev1EnergyIntegral, 0.18);
      expect(result.fvcEnergyIntegral, 0.2);
      expect(result.fev1FvcRatioPercent, 90);
      expect(result.peakFlowIndex, 75);
      expect(result.peakFlowAtMs, 200);
    });

    test('leaves spirometry fields null when no estimate is passed', () {
      final result = build();

      expect(result.fev1EnergyIntegral, isNull);
      expect(result.fvcEnergyIntegral, isNull);
      expect(result.fev1FvcRatioPercent, isNull);
      expect(result.peakFlowIndex, isNull);
      expect(result.peakFlowAtMs, isNull);
    });

    test('breathScore/riskContribution are identical whether or not spirometry '
        'is passed — spirometry is presentation-only and must never silently '
        'enter the risk formula', () {
      final withSpirometry = build(spirometry: spirometry);
      final withoutSpirometry = build();

      expect(withSpirometry.breathScore, withoutSpirometry.breathScore);
      expect(
        withSpirometry.riskContribution,
        withoutSpirometry.riskContribution,
      );
    });
  });
}
