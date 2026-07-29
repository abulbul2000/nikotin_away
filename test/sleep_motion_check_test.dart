import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The sleep-window "is the user actually awake" check used to rely on
/// PowerManager.isInteractive alone (is the screen on). That reads a phone
/// left playing video on a nightstand as "in use" for as long as the video
/// runs — media playback keeps the screen on and blocks auto-lock — which is
/// exactly the false positive the user reported: woken by a mandatory task
/// while genuinely asleep because YouTube was still going.
void main() {
  final file = File(
    'android/app/src/main/kotlin/com/example/no_smoke/SleepProbeReceiver.kt',
  );

  test('screen-on alone no longer decides "awake" during the sleep window', () {
    final source = file.readAsStringSync();
    expect(source, contains('MotionSampler'));
    expect(
      source,
      contains('readMotionThenDecide'),
      reason: 'the screen-on branch must sample motion before enqueuing activity',
    );
  });

  test('the motion sample is one-shot, not a standing listener', () {
    final source = file.readAsStringSync();
    // A listener kept alive all night is the exact battery cost the probe's
    // own design notes call out avoiding elsewhere in this file.
    expect(source, contains('unregisterListener'));
  });

  test('a device with no accelerometer fails toward the old behaviour', () {
    final source = file.readAsStringSync();
    // Going quiet all night on a device that can't run the check would be a
    // worse regression than the false positive this exists to fix.
    final sampleFn = RegExp(
      r'fun sample\(context: Context, callback: \(Boolean\) -> Unit\) \{([\s\S]*?)\n    \}',
    ).firstMatch(source);
    expect(sampleFn, isNotNull);
    expect(sampleFn!.group(1), contains('callback(true)'));
  });
}
