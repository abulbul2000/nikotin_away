class BreathTrendAnalysis {
  final double averageBreathScore;
  final String trendLast3;
  final String trendLast7;
  final int riskAdjustment;

  const BreathTrendAnalysis({
    required this.averageBreathScore,
    required this.trendLast3,
    required this.trendLast7,
    required this.riskAdjustment,
  });
}
