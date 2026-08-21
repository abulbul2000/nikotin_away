/// One screen of the pre-sleep routine, in display order.
enum SleepRoutineStep {
  breathTest,
  coughTest,
  nextDayWakeTime,
  dailyReport,
}

/// Decides which steps the pre-sleep routine shows, and in what order.
///
/// Pure — no I/O. Kept out of `SleepRoutinePage` so the widget doesn't have
/// to build its own `if` chain. The wake-time question belongs to this flow
/// because sleep intelligence needs the next calendar day's plan, including
/// weekday/weekend differences, before it can schedule a morning report.
class SleepRoutineFlowEngine {
  const SleepRoutineFlowEngine();

  List<SleepRoutineStep> buildSteps({bool hasDiscrepancy = false}) => const [
    SleepRoutineStep.breathTest,
    SleepRoutineStep.coughTest,
    SleepRoutineStep.nextDayWakeTime,
    SleepRoutineStep.dailyReport,
  ];
}
