class BreathTestResult {
  final String id;
  final DateTime createdAt;
  final double holdDuration;
  final double blowDuration;
  final double blowIntensity;
  final double blowStability;
  final int holdRisk;
  final int blowRisk;
  final int intensityRisk;
  final int stabilityRisk;
  final double breathScore;
  final double riskContribution;

  /// Spirometry-style estimates derived from the exhale's acoustic
  /// energy-time curve (see BreathAcousticEngine.estimateSpirometry). Null
  /// when no full acoustic reading was available for the attempt (mic
  /// denied, detection failed) or for rows saved before this field existed.
  /// Deliberately excluded from [breathScore]/[riskContribution] — these are
  /// presentation-only estimates, not a risk-scoring input.
  final double? fev1EnergyIntegral;
  final double? fvcEnergyIntegral;
  final double? fev1FvcRatioPercent;
  final double? peakFlowIndex;
  final int? peakFlowAtMs;

  const BreathTestResult({
    required this.id,
    required this.createdAt,
    required this.holdDuration,
    required this.blowDuration,
    required this.blowIntensity,
    required this.blowStability,
    required this.holdRisk,
    required this.blowRisk,
    required this.intensityRisk,
    required this.stabilityRisk,
    required this.breathScore,
    required this.riskContribution,
    this.fev1EnergyIntegral,
    this.fvcEnergyIntegral,
    this.fev1FvcRatioPercent,
    this.peakFlowIndex,
    this.peakFlowAtMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'holdDuration': holdDuration,
      'blowDuration': blowDuration,
      'blowIntensity': blowIntensity,
      'blowStability': blowStability,
      'holdRisk': holdRisk,
      'blowRisk': blowRisk,
      'intensityRisk': intensityRisk,
      'stabilityRisk': stabilityRisk,
      'breathScore': breathScore,
      'riskContribution': riskContribution,
      'fev1EnergyIntegral': fev1EnergyIntegral,
      'fvcEnergyIntegral': fvcEnergyIntegral,
      'fev1FvcRatioPercent': fev1FvcRatioPercent,
      'peakFlowIndex': peakFlowIndex,
      'peakFlowAtMs': peakFlowAtMs,
    };
  }

  factory BreathTestResult.fromJson(Map<String, dynamic> json) {
    return BreathTestResult(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      holdDuration: (json['holdDuration'] as num).toDouble(),
      blowDuration: (json['blowDuration'] as num).toDouble(),
      blowIntensity: (json['blowIntensity'] as num).toDouble(),
      blowStability: (json['blowStability'] as num).toDouble(),
      holdRisk: (json['holdRisk'] as num).toInt(),
      blowRisk: (json['blowRisk'] as num).toInt(),
      intensityRisk: (json['intensityRisk'] as num).toInt(),
      stabilityRisk: (json['stabilityRisk'] as num).toInt(),
      breathScore: (json['breathScore'] as num).toDouble(),
      riskContribution: (json['riskContribution'] as num).toDouble(),
      fev1EnergyIntegral: (json['fev1EnergyIntegral'] as num?)?.toDouble(),
      fvcEnergyIntegral: (json['fvcEnergyIntegral'] as num?)?.toDouble(),
      fev1FvcRatioPercent: (json['fev1FvcRatioPercent'] as num?)?.toDouble(),
      peakFlowIndex: (json['peakFlowIndex'] as num?)?.toDouble(),
      peakFlowAtMs: (json['peakFlowAtMs'] as num?)?.toInt(),
    );
  }
}
