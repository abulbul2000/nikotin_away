class SleepProbeEvent {
  final String id;
  final DateTime createdAt;
  final bool screenOff;
  final bool charging;

  const SleepProbeEvent({
    required this.id,
    required this.createdAt,
    required this.screenOff,
    required this.charging,
  });
}
