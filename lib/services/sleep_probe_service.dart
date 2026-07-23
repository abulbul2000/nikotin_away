import 'package:flutter/services.dart';

/// Thin wrapper around the native `no_smoke/sleep_probe` channel, which arms
/// an AlarmManager-driven chain (see SleepProbeReceiver.kt) that samples
/// free OS signals (screen-interactive + charging state) every ~45 minutes
/// overnight and writes them straight to SQLite — no Dart isolate needs to
/// be alive for it to work. Kept as a plain wrapper so all scheduling policy
/// (window buffer, interval) lives in one place: SleepIntelligenceService.
class SleepProbeService {
  static const MethodChannel _channel = MethodChannel('no_smoke/sleep_probe');
  static const int defaultIntervalMinutes = 45;

  static Future<void> scheduleNightlyProbing({
    required int windowStartMinute,
    required int windowEndMinute,
    int intervalMinutes = defaultIntervalMinutes,
  }) async {
    try {
      await _channel.invokeMethod('scheduleNightlyProbing', {
        'windowStartMinute': windowStartMinute,
        'windowEndMinute': windowEndMinute,
        'intervalMinutes': intervalMinutes,
      });
    } catch (_) {
      // Best-effort on platforms without this channel (e.g. iOS, tests).
    }
  }

  static Future<void> cancelNightlyProbing() async {
    try {
      await _channel.invokeMethod('cancelNightlyProbing');
    } catch (_) {
      // Best-effort.
    }
  }
}
