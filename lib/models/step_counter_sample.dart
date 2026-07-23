/// One reading of the device's cumulative hardware step counter (steps
/// since last reboot). Written natively — once daily near midnight
/// (StepProbeReceiver.kt) and once per throttled app-open — so
/// StepTrendEngine always has a sample close to each day boundary.
class StepCounterSample {
  final String id;
  final DateTime createdAt;
  final int cumulativeSteps;

  const StepCounterSample({
    required this.id,
    required this.createdAt,
    required this.cumulativeSteps,
  });
}
