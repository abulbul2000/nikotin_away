/// A best-effort read of whatever heart-rate/sleep data Health Connect
/// currently has on-device (Phase 9 wearable spike). Any field can be null —
/// the user may have no wearable, no synced app, or simply no recent data —
/// callers must treat every field as optional and degrade silently.
class WearableHealthSnapshot {
  final double? latestHeartRateBpm;
  final DateTime? latestHeartRateAt;
  final double? baselineHeartRateBpm;
  final Duration? lastSleepSessionDuration;
  final DateTime? lastSleepSessionEnd;

  const WearableHealthSnapshot({
    this.latestHeartRateBpm,
    this.latestHeartRateAt,
    this.baselineHeartRateBpm,
    this.lastSleepSessionDuration,
    this.lastSleepSessionEnd,
  });

  static const empty = WearableHealthSnapshot();

  bool get hasAnyData =>
      latestHeartRateBpm != null || lastSleepSessionDuration != null;
}
