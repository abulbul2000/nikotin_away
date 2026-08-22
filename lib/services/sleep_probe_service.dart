import 'package:flutter/services.dart';

/// Thin wrapper around the native `no_smoke/sleep_probe` channel, which arms
/// an AlarmManager-driven chain (see SleepProbeReceiver.kt) that samples
/// free OS signals (screen-interactive + charging state) every ~5 minutes
/// overnight and writes them straight to SQLite — no Dart isolate needs to
/// be alive for it to work. Kept as a plain wrapper so all scheduling policy
/// (window buffer, interval) lives in one place: SleepIntelligenceService.
class SleepProbeService {
  static const MethodChannel _channel = MethodChannel('no_smoke/sleep_probe');
  // A 15-minute interval keeps overnight wake-ups bounded while still
  // providing enough coverage for sleep-window learning. The probe is not a
  // clock-critical alarm; notification/task delivery uses its own schedule.
  static const int defaultIntervalMinutes = 15;

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

  /// Flips the flag the native probe reads each tick to decide whether to
  /// also run a short snoring-detection audio capture (see
  /// SnoringDetectionService) -- piggybacks on this same alarm schedule
  /// rather than arming a separate one.
  static Future<void> setSnoringDetectionEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSnoringDetectionEnabled', {
        'enabled': enabled,
      });
    } catch (_) {
      // Best-effort.
    }
  }

  /// Pushes the localized notification text SnoringCaptureService's required
  /// foreground-service notification shows during each overnight capture —
  /// same "Dart pushes strings, native falls back to English defaults if it
  /// hasn't received them yet" pattern as
  /// AndroidWatchdogService.setTaskOverlayChannelInfo. A fixed, locale-only
  /// text (not tied to any one capture), so it's pushed once at app startup
  /// rather than on every capture.
  static Future<void> setSnoringCaptureChannelInfo({
    required String title,
    required String body,
    required String channelName,
  }) async {
    try {
      await _channel.invokeMethod('setSnoringCaptureChannelInfo', {
        'title': title,
        'body': body,
        'channelName': channelName,
      });
    } catch (_) {
      // Best-effort: falls back to the service's own English defaults.
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
