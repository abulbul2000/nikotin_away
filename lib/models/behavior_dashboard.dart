import 'adaptive_plan.dart';

class BehaviorDashboard {
  final int riskScore;
  final List<String> riskyTriggers;
  final List<String> riskyHours;
  final DateTime? lastSurveyDate;
  final DateTime? lastBreathDate;
  final String breathTrend;
  final String progressSummary;
  final List<String> todaysTasks;
  final List<String> coachCommands;
  final List<String> durationBarrierCommands;
  final int durationBarrierHistoryCount;
  final Map<String, double> commandSuccessScores;
  final Map<String, double> commandCategoryScores;
  final String commandMixMode;
  final int weeklySurveyRiskScore;
  final String weeklySurveyRiskLevel;
  final List<String> weeklyTopRiskDrivers;
  final List<String> riskExplanation;
  final Map<String, double> learnedWeights;
  final String predictedRiskWindow;
  final int predictionConfidence;
  final String predictedTrigger;
  final AdaptivePlan plan;

  const BehaviorDashboard({
    required this.riskScore,
    required this.riskyTriggers,
    required this.riskyHours,
    this.lastSurveyDate,
    this.lastBreathDate,
    required this.breathTrend,
    required this.progressSummary,
    required this.todaysTasks,
    required this.coachCommands,
    required this.durationBarrierCommands,
    required this.durationBarrierHistoryCount,
    required this.commandSuccessScores,
    required this.commandCategoryScores,
    required this.commandMixMode,
    required this.weeklySurveyRiskScore,
    required this.weeklySurveyRiskLevel,
    required this.weeklyTopRiskDrivers,
    required this.riskExplanation,
    required this.learnedWeights,
    required this.predictedRiskWindow,
    required this.predictionConfidence,
    required this.predictedTrigger,
    required this.plan,
  });
}
