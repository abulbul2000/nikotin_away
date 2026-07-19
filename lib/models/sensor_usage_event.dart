class SensorUsageEvent {
  final String id;
  final DateTime createdAt;
  final String activityState;
  final double accelerometerMagnitude;
  final double gyroscopeMagnitude;
  final double ambientMeanDecibel;
  final double ambientPeakDecibel;
  final double mealSoundLikelihood;
  final int screenUnlockCount;
  final int appUsageMinutes;
  final int idleMinutes;
  final bool charging;

  const SensorUsageEvent({
    required this.id,
    required this.createdAt,
    required this.activityState,
    required this.accelerometerMagnitude,
    required this.gyroscopeMagnitude,
    this.ambientMeanDecibel = 0,
    this.ambientPeakDecibel = 0,
    this.mealSoundLikelihood = 0,
    required this.screenUnlockCount,
    required this.appUsageMinutes,
    required this.idleMinutes,
    required this.charging,
  });
}
