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
    );
  }
}
