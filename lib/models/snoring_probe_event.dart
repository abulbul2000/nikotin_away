class SnoringProbeEvent {
  final String id;
  final DateTime createdAt;
  final bool snoreLikely;

  const SnoringProbeEvent({
    required this.id,
    required this.createdAt,
    required this.snoreLikely,
  });
}
