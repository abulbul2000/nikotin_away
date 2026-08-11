import '../models/smoking_count_discrepancy.dart';

/// Decides whether today's logged cigarette count is suspiciously low next
/// to what the user's survey answers say they typically smoke.
///
/// Pure — no I/O. `StorageService.evaluateTodaySmokingDiscrepancy` gathers
/// the inputs and calls this.
class SmokingCountDiscrepancyEngine {
  const SmokingCountDiscrepancyEngine();

  /// How many cigarettes short of the declared average today's log has to
  /// be before the pre-sleep routine asks about it. A fixed, product-decided
  /// threshold rather than something tunable.
  static const int discrepancyThreshold = 3;

  SmokingCountDiscrepancy evaluate({
    required int loggedCount,
    required int declaredDailyAverage,
  }) {
    final gap = declaredDailyAverage - loggedCount;
    return SmokingCountDiscrepancy(
      loggedCount: loggedCount,
      declaredDailyAverage: declaredDailyAverage,
      gap: gap,
      // A negative gap means today's log already exceeds the declared
      // average — the user is over-logging, not under-logging, so the
      // question would be nonsensical.
      hasDiscrepancy: gap >= discrepancyThreshold,
    );
  }
}
