import 'dart:math';

import '../models/breath_test_result.dart';
import '../models/breath_trend_analysis.dart';
import 'breath_acoustic_engine.dart';

class BreathTestEngine {
  int holdRisk(double holdDuration) {
    if (holdDuration < 10) {
      return 100;
    }
    if (holdDuration < 20) {
      return 80;
    }
    if (holdDuration < 30) {
      return 60;
    }
    if (holdDuration < 45) {
      return 40;
    }
    if (holdDuration < 60) {
      return 20;
    }
    return 10;
  }

  int blowDurationRisk(double blowDuration) {
    if (blowDuration < 3) {
      return 100;
    }
    if (blowDuration < 5) {
      return 80;
    }
    if (blowDuration < 8) {
      return 60;
    }
    if (blowDuration < 10) {
      return 40;
    }
    return 20;
  }

  int stabilityRisk(double stability) {
    final safe = stability.clamp(0, 1).toDouble();
    return ((1 - safe) * 100).round().clamp(0, 100);
  }

  int intensityRisk(double intensity) {
    final safe = intensity.clamp(0, 1).toDouble();
    return ((1 - safe) * 100).round().clamp(0, 100);
  }

  double breathScore({
    required int holdRisk,
    required int blowRisk,
    required int stabilityRisk,
    required int intensityRisk,
  }) {
    final score =
        (holdRisk * 0.40) +
        (blowRisk * 0.30) +
        (stabilityRisk * 0.15) +
        (intensityRisk * 0.15);
    return score.clamp(0, 100).toDouble();
  }

  int calculateFinalRisk({
    required double surveyRisk,
    required double behaviorRisk,
    required double taskPerformanceRisk,
    required double breathScore,
    int trendAdjustment = 0,
    double surveyWeight = 0.40,
    double behaviorWeight = 0.25,
    double taskWeight = 0.15,
    double breathWeight = 0.20,
  }) {
    final weighted =
        (surveyRisk * surveyWeight) +
        (behaviorRisk * behaviorWeight) +
        (taskPerformanceRisk * taskWeight) +
        (breathScore * breathWeight);
    return (weighted + trendAdjustment).round().clamp(0, 100);
  }

  String resolveRiskLevel(int riskScore) {
    if (riskScore <= 24) {
      return 'DÜŞÜK';
    }
    if (riskScore <= 49) {
      return 'ORTA';
    }
    if (riskScore <= 74) {
      return 'YÜKSEK';
    }
    return 'KRİTİK';
  }

  BreathTrendAnalysis analyzeTrend(List<BreathTestResult> results) {
    if (results.isEmpty) {
      return const BreathTrendAnalysis(
        averageBreathScore: 50,
        trendLast3: 'stable',
        trendLast7: 'stable',
        riskAdjustment: 0,
      );
    }

    final sorted = [...results]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final scores = sorted.map((item) => item.breathScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;

    final trend3 = _trendLabel(scores.length >= 3 ? scores.sublist(scores.length - 3) : scores);
    final trend7 = _trendLabel(scores.length >= 7 ? scores.sublist(scores.length - 7) : scores);

    var adjustment = 0;
    if (_isStrictlyImproving(scores, count: 5)) {
      adjustment -= 5;
    } else if (_isStrictlyWorsening(scores, count: 7)) {
      adjustment += 5;
    }

    return BreathTrendAnalysis(
      averageBreathScore: average,
      trendLast3: trend3,
      trendLast7: trend7,
      riskAdjustment: adjustment,
    );
  }

  /// [spirometry], when present, is copied onto the result as presentation
  /// fields only — it never enters [breathScore]/[riskContribution] below.
  /// These estimates come from an uncalibrated acoustic proxy (see
  /// SpirometryEstimate's doc comment); folding them into the same formula
  /// that drives real coaching decisions (MentorEngine) would let mic
  /// distance/case muffling/ambient noise silently swing the actual risk
  /// score under a professional-looking label. [spirometry] is null when no
  /// full acoustic reading was available for the attempt.
  BreathTestResult buildResult({
    required String id,
    required DateTime createdAt,
    required double holdDuration,
    required double blowDuration,
    required double blowIntensity,
    required double blowStability,
    SpirometryEstimate? spirometry,
  }) {
    final computedHoldRisk = holdRisk(holdDuration);
    final computedBlowRisk = blowDurationRisk(blowDuration);
    final computedStabilityRisk = stabilityRisk(blowStability);
    final computedIntensityRisk = intensityRisk(blowIntensity);

    final score = breathScore(
      holdRisk: computedHoldRisk,
      blowRisk: computedBlowRisk,
      stabilityRisk: computedStabilityRisk,
      intensityRisk: computedIntensityRisk,
    );

    return BreathTestResult(
      id: id,
      createdAt: createdAt,
      holdDuration: holdDuration,
      blowDuration: blowDuration,
      blowIntensity: blowIntensity.clamp(0, 1).toDouble(),
      blowStability: blowStability.clamp(0, 1).toDouble(),
      holdRisk: computedHoldRisk,
      blowRisk: computedBlowRisk,
      intensityRisk: computedIntensityRisk,
      stabilityRisk: computedStabilityRisk,
      breathScore: score,
      riskContribution: score * 0.20,
      fev1EnergyIntegral: spirometry?.fev1EnergyIntegral,
      fvcEnergyIntegral: spirometry?.fvcEnergyIntegral,
      fev1FvcRatioPercent: spirometry?.fev1FvcRatioPercent,
      peakFlowIndex: spirometry?.peakFlowIndex,
      peakFlowAtMs: spirometry?.peakFlowAtMs,
    );
  }

  double estimateBlowStabilityFromAttempts(List<int> attempts) {
    if (attempts.isEmpty) {
      return 0.5;
    }
    if (attempts.length == 1) {
      return 0.7;
    }

    final mean = attempts.reduce((a, b) => a + b) / attempts.length;
    if (mean <= 0) {
      return 0.0;
    }

    final variance = attempts
            .map((value) => pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        attempts.length;
    final stdDev = sqrt(variance);
    final normalized = (1 - (stdDev / mean)).clamp(0, 1);
    return normalized.toDouble();
  }

  double estimateBlowIntensity({
    required double holdDuration,
    required double blowDuration,
  }) {
    final blowSignal = (blowDuration / 10).clamp(0, 1).toDouble();
    final holdSignal = (holdDuration / 60).clamp(0, 1).toDouble();
    return ((blowSignal * 0.7) + (holdSignal * 0.3)).clamp(0, 1).toDouble();
  }

  String _trendLabel(List<double> values) {
    if (values.length < 2) {
      return 'stable';
    }
    final first = values.first;
    final last = values.last;
    if (last < first - 2) {
      return 'improving';
    }
    if (last > first + 2) {
      return 'worsening';
    }
    return 'stable';
  }

  bool _isStrictlyImproving(List<double> values, {required int count}) {
    if (values.length < count) {
      return false;
    }
    final window = values.sublist(values.length - count);
    for (var i = 1; i < window.length; i++) {
      if (window[i] >= window[i - 1]) {
        return false;
      }
    }
    return true;
  }

  bool _isStrictlyWorsening(List<double> values, {required int count}) {
    if (values.length < count) {
      return false;
    }
    final window = values.sublist(values.length - count);
    for (var i = 1; i < window.length; i++) {
      if (window[i] <= window[i - 1]) {
        return false;
      }
    }
    return true;
  }
}
