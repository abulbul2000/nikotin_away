import 'package:flutter/services.dart';

/// Thin wrapper around the native `no_smoke/steps` channel. The actual
/// sensor read and the daily midnight probe both live natively
/// (MainActivity.kt / StepProbeReceiver.kt) since TYPE_STEP_COUNTER is a
/// hardware-batched Android sensor with no Dart-side equivalent, and the
/// daily probe needs to fire without the Flutter engine running.
class StepCounterService {
  static const MethodChannel _channel = MethodChannel('no_smoke/steps');

  static Future<int?> readCurrentStepCount() async {
    try {
      final result = await _channel.invokeMethod<int>('readCurrentStepCount');
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<void> scheduleDailyStepProbe() async {
    try {
      await _channel.invokeMethod('scheduleDailyStepProbe');
    } catch (_) {
      // Best-effort on platforms without this channel (e.g. iOS, tests).
    }
  }

  static Future<void> cancelDailyStepProbe() async {
    try {
      await _channel.invokeMethod('cancelDailyStepProbe');
    } catch (_) {
      // Best-effort.
    }
  }
}
