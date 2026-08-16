class UserBehaviorProfile {
  final int riskScore;
  final List<String> riskyTriggers;
  final List<String> riskyHours;
  final Map<String, Map<String, dynamic>> successfulTasks;
  final Map<String, Map<String, dynamic>> failedTasks;
  final String breathTrend;
  final String smokingTrend;
  final String riskTrend;
  final String consecutiveSmokingTrend;
  final String consecutiveSmokingStatus;
  final String progressStatus;
  final List<String> suggestedTasks;
  final DateTime? lastSurveyDate;
  final String subscriptionType;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool trialActive;
  final bool premiumFeaturesEnabled;
  final String dataConfidence;
  final String dataFreshness;
  final String recoveryMode;
  final List<String> suggestionReasons;

  const UserBehaviorProfile({
    required this.riskScore,
    required this.riskyTriggers,
    required this.riskyHours,
    required this.successfulTasks,
    required this.failedTasks,
    required this.breathTrend,
    required this.smokingTrend,
    required this.riskTrend,
    required this.consecutiveSmokingTrend,
    required this.consecutiveSmokingStatus,
    required this.progressStatus,
    required this.suggestedTasks,
    this.lastSurveyDate,
    this.subscriptionType = 'free',
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.trialActive = false,
    this.premiumFeaturesEnabled = false,
    this.dataConfidence = 'low',
    this.dataFreshness = 'noData',
    this.recoveryMode = 'steady',
    this.suggestionReasons = const [],
  });
}
