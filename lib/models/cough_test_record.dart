class CoughTestRecord {
  final String id;
  final DateTime createdAt;
  final int coughCount;
  final int testDurationSeconds;
  final int severityScore;
  final String severityLevel;

  /// Mean gap between consecutive coughs, in seconds. Null when fewer than
  /// two coughs were detected (no interval to average).
  final double? averageIntervalSeconds;

  /// Share (0.0-1.0) of coughs that landed in the first third of the test
  /// window — a burst concentrated early reads differently from one spread
  /// evenly across the recording. Null when no coughs were detected.
  final double? earlyBurstRatio;

  /// Normalized (0-100) energy of the loudest single cough event relative
  /// to the test's own background noise floor. Null when no coughs were
  /// detected.
  final int? peakIntensityScore;

  /// Acoustic wheeze finding from the same recording (see
  /// WheezeDetectionEngine.analyze). Null when no sustained wheeze was
  /// found, or for rows saved before this field existed.
  final bool? wheezeDetected;
  final String? wheezeSeverityLevel;
  final int? wheezeSeverityScore;
  final double? wheezeBandEnergyRatio;

  /// True when the recording never cleared the microphone's noise floor at
  /// all (see CoughAcousticEngine.analyze's insufficientSignal) — the user
  /// chose to keep this attempt rather than retry, so coughCount/
  /// severityLevel are the engine's zero-signal defaults, not a real
  /// reading. False/null (including every row saved before this field
  /// existed) means the recording captured real audio, whether or not any
  /// coughs were found in it.
  final bool? insufficientSignal;

  const CoughTestRecord({
    required this.id,
    required this.createdAt,
    required this.coughCount,
    required this.testDurationSeconds,
    required this.severityScore,
    required this.severityLevel,
    this.averageIntervalSeconds,
    this.earlyBurstRatio,
    this.peakIntensityScore,
    this.wheezeDetected,
    this.wheezeSeverityLevel,
    this.wheezeSeverityScore,
    this.wheezeBandEnergyRatio,
    this.insufficientSignal,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'coughCount': coughCount,
      'testDurationSeconds': testDurationSeconds,
      'severityScore': severityScore,
      'severityLevel': severityLevel,
      'averageIntervalSeconds': averageIntervalSeconds,
      'earlyBurstRatio': earlyBurstRatio,
      'peakIntensityScore': peakIntensityScore,
      'wheezeDetected': wheezeDetected == null
          ? null
          : (wheezeDetected! ? 1 : 0),
      'wheezeSeverityLevel': wheezeSeverityLevel,
      'wheezeSeverityScore': wheezeSeverityScore,
      'wheezeBandEnergyRatio': wheezeBandEnergyRatio,
      'insufficientSignal': insufficientSignal == null
          ? null
          : (insufficientSignal! ? 1 : 0),
    };
  }

  factory CoughTestRecord.fromJson(Map<String, dynamic> json) {
    return CoughTestRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      coughCount: (json['coughCount'] as num).toInt(),
      testDurationSeconds: (json['testDurationSeconds'] as num).toInt(),
      severityScore: (json['severityScore'] as num).toInt(),
      severityLevel: json['severityLevel'] as String,
      averageIntervalSeconds: (json['averageIntervalSeconds'] as num?)
          ?.toDouble(),
      earlyBurstRatio: (json['earlyBurstRatio'] as num?)?.toDouble(),
      peakIntensityScore: (json['peakIntensityScore'] as num?)?.toInt(),
      wheezeDetected: (json['wheezeDetected'] as num?) == null
          ? null
          : (json['wheezeDetected'] as num).toInt() == 1,
      wheezeSeverityLevel: json['wheezeSeverityLevel'] as String?,
      wheezeSeverityScore: (json['wheezeSeverityScore'] as num?)?.toInt(),
      wheezeBandEnergyRatio: (json['wheezeBandEnergyRatio'] as num?)
          ?.toDouble(),
      insufficientSignal: (json['insufficientSignal'] as num?) == null
          ? null
          : (json['insufficientSignal'] as num).toInt() == 1,
    );
  }
}
