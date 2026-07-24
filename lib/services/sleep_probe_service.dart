import 'package:flutter/services.dart';

/// Thin wrapper around the native `no_smoke/sleep_probe` channel, which arms
/// an AlarmManager-driven chain (see SleepProbeReceiver.kt) that samples
/// free OS signals (screen-interactive + charging state) every ~5 minutes
/// overnight and writes them straight to SQLite — no Dart isolate needs to
/// be alive for it to work. Kept as a plain wrapper so all scheduling policy
/// (window buffer, interval) lives in one place: SleepIntelligenceService.
class SleepProbeService {
  static const MethodChannel _channel = MethodChannel('no_smoke/sleep_probe');
  // Was 45 -- tightened so a user awake mid-sleep-window gets noticed
  // within a few minutes instead of up to 45 (see
  // SleepProbeReceiver.DEFAULT_INTERVAL_MINUTES for the native-side reasoning).
  static const int defaultIntervalMinutes = 5;

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

  /// Drains queued "user was awake during their sleep window" timestamps
  /// (epoch millis, as strings) recorded by the native probe. Best-effort:
  /// an empty list either means nothing happened, or the channel/platform
  /// doesn't support it -- both are safe to treat the same way.
  static Future<List<int>> consumeSleepActivityEvents() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'consumeSleepActivityEvents',
      );
      if (raw == null) {
        return const [];
      }
      return raw
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
