class SnoringProbeEvent {
  final String id;
  final DateTime createdAt;
  final bool snoreLikely;

  /// 0-100, null for probes recorded before severity scoring was added.
  final int? severityScore;

  /// 'none' | 'mild' | 'moderate' | 'severe', null for probes recorded
  /// before severity scoring was added.
  final String? severityLevel;

  /// Whether the microphone capture behind this row actually completed —
  /// false means permission was revoked mid-call, AudioRecord couldn't
  /// initialize, or the foreground service couldn't start (see
  /// SnoringCaptureService.kt), and [snoreLikely]/[severityScore]/
  /// [severityLevel] are meaningless defaults, not a real "no snoring"
  /// reading. Null for probes recorded before this field existed — treated
  /// as true (the old, pre-Android-11-fix assumption) since those rows
  /// predate the failure mode this field distinguishes.
  final bool? captureSucceeded;

  const SnoringProbeEvent({
    required this.id,
    required this.createdAt,
    required this.snoreLikely,
    this.severityScore,
    this.severityLevel,
    this.captureSucceeded,
  });
}
