/// What the home page shows instead of a smoke-free day count.
///
/// The app's goal is gradual reduction, not abstinence, so "days since you
/// quit" measures nothing the user is actually being asked to do — and the
/// counter it replaced never even checked whether they had smoked. Every
/// figure here is derived from something the user did or didn't do.
class ReductionProgress {
  const ReductionProgress({
    required this.targetStreakDays,
    required this.cigarettesAvoided,
    required this.naturalIntervalMinutes,
    required this.currentBarrierMinutes,
    required this.dailyTarget,
    required this.baselineDaily,
    required this.loggedToday,
    required this.evidenceDays,
    this.longestCompletedBarrierMinutes = 0,
  });

  /// Consecutive days, counting back from the most recent day with evidence,
  /// on which the user stayed at or under [dailyTarget].
  final int targetStreakDays;

  /// Cigarettes not smoked, summed only over days we have evidence for.
  /// Days the user logged nothing contribute zero rather than a full
  /// baseline's worth — silence is not achievement.
  final int cigarettesAvoided;

  /// The gap between cigarettes the user's own survey answers imply.
  final int naturalIntervalMinutes;

  /// The gap being asked of them right now.
  final int currentBarrierMinutes;

  /// Cigarettes a day the current barrier works out to.
  final int dailyTarget;

  /// Cigarettes a day they reported at the start.
  final int baselineDaily;

  /// Today's count, or null when nothing has been logged today yet.
  final int? loggedToday;

  /// How many distinct days contributed to these figures. Zero means the
  /// card has nothing real to show and should say so rather than print
  /// three confident zeros.
  final int evidenceDays;

  /// The longest barrier ever actually completed (a `success` outcome), in
  /// minutes — the natural personal-record figure the "longest interval"
  /// achievement badge is measured against.
  final int longestCompletedBarrierMinutes;

  bool get hasEvidence => evidenceDays > 0;

  /// How far the barrier has moved from the user's natural gap, as a
  /// fraction. 0.0 on day one; 0.25 once they're waiting a quarter longer
  /// between cigarettes than they used to.
  double get intervalProgress {
    if (naturalIntervalMinutes <= 0) return 0;
    final gained = currentBarrierMinutes - naturalIntervalMinutes;
    if (gained <= 0) return 0;
    return gained / naturalIntervalMinutes;
  }

  static const empty = ReductionProgress(
    targetStreakDays: 0,
    cigarettesAvoided: 0,
    naturalIntervalMinutes: 0,
    currentBarrierMinutes: 0,
    dailyTarget: 0,
    baselineDaily: 0,
    loggedToday: null,
    evidenceDays: 0,
  );
}
