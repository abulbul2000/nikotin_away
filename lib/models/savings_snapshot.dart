class SavingsSnapshot {
  final double moneySaved;
  final int cigarettesNotSmoked;
  final Duration lifeTimeRegained; // rough estimate: 11 min per cigarette avoided

  const SavingsSnapshot({
    required this.moneySaved,
    required this.cigarettesNotSmoked,
    required this.lifeTimeRegained,
  });
}
