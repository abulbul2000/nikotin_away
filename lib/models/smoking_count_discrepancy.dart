/// How today's logged cigarette count compares to what the user's survey
/// answers say they typically smoke.
///
/// Pure data — [SmokingCountDiscrepancyEngine] in
/// `smoking_count_discrepancy_engine.dart` is what decides [hasDiscrepancy];
/// this class only carries the result.
class SmokingCountDiscrepancy {
  const SmokingCountDiscrepancy({
    required this.loggedCount,
    required this.declaredDailyAverage,
    required this.gap,
    required this.hasDiscrepancy,
  });

  /// How many cigarettes were logged today via the quick-log button.
  final int loggedCount;

  /// The daily average implied by the user's most recent survey answers.
  final int declaredDailyAverage;

  /// [declaredDailyAverage] minus [loggedCount]. Negative when today's log
  /// already exceeds the declared average.
  final int gap;

  final bool hasDiscrepancy;
}
