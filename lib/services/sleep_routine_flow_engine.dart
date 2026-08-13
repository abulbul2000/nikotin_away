/// One screen of the pre-sleep routine, in display order.
enum SleepRoutineStep {
  breathTest,
  coughTest,
  smokingDiscrepancyQuestion,
  dailyReport,
}

/// Decides which steps the pre-sleep routine shows, and in what order.
///
/// Pure — no I/O. Kept out of `SleepRoutinePage` so the widget doesn't have
/// to build its own `if` chain to decide whether the discrepancy question
/// belongs in the flow; the order is tested here once instead of by
/// poking the widget.
class SleepRoutineFlowEngine {
  const SleepRoutineFlowEngine();

  List<SleepRoutineStep> buildSteps({required bool hasDiscrepancy}) => [
    SleepRoutineStep.breathTest,
    SleepRoutineStep.coughTest,
    if (hasDiscrepancy) SleepRoutineStep.smokingDiscrepancyQuestion,
    SleepRoutineStep.dailyReport,
  ];
}
