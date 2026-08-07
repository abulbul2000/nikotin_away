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
    );
  }
}
