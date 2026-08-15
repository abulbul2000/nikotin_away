class PeriodReport {
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodType; // 'weekly' | 'monthly'
  final int cigarettesLogged;
  final double avgCigarettesPerDay;
  final int? riskScoreAtStart;
  final int? riskScoreAtEnd;
  final String riskTrend; // 'Improving' | 'Declining' | 'Stable'
  final String breathTrend;
  final String smokingTrend;
  final int taskSuccessCount;
  final int taskFailureCount;
  final double taskCompletionRate;
  final int weeklySurveysCompleted;
  final int breathTestsCompleted;
  final int? daysSinceQuitDate;
  final int totalSteps;
  final double avgStepsPerDay;

  /// An estimate of how many cigarettes were not smoked in this period,
  /// compared with the user's baseline average before the period. Null
  /// whenever there is not enough data — never invented.
  final int? estimatedAvertedCigarettes;

  /// Where logged cigarettes fall across the day. Null when there are too
  /// few events to speak about a pattern. Map keys are
  /// 'morning' | 'midday' | 'afternoon' | 'evening' | 'night'.
  final Map<String, double>? smokingTimePattern;
  const PeriodReport({
    required this.periodStart,
    required this.periodEnd,
    required this.periodType,
    required this.cigarettesLogged,
    required this.avgCigarettesPerDay,
    required this.riskScoreAtStart,
    required this.riskScoreAtEnd,
    required this.riskTrend,
    required this.breathTrend,
    required this.smokingTrend,
    required this.taskSuccessCount,
    required this.taskFailureCount,
    required this.taskCompletionRate,
    required this.weeklySurveysCompleted,
    required this.breathTestsCompleted,
    required this.daysSinceQuitDate,
    required this.totalSteps,
    required this.avgStepsPerDay,
    this.estimatedAvertedCigarettes,
    this.smokingTimePattern,
  });
}
