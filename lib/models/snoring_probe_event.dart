class SnoringProbeEvent {
  final String id;
  final DateTime createdAt;
  final bool snoreLikely;

  /// 0-100, null for probes recorded before severity scoring was added.
  final int? severityScore;

  /// 'none' | 'mild' | 'moderate' | 'severe', null for probes recorded
  /// before severity scoring was added.
  final String? severityLevel;

  const SnoringProbeEvent({
    required this.id,
    required this.createdAt,
    required this.snoreLikely,
    this.severityScore,
    this.severityLevel,
  });
}
