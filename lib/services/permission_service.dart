import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

class OnboardingPermissionResult {
  final bool telemetryGranted;
  final bool notificationsGranted;

  const OnboardingPermissionResult({
    required this.telemetryGranted,
    required this.notificationsGranted,
  });
}

class PermissionService {
  static Future<OnboardingPermissionResult> requestOnboardingPermissions() async {
    final telemetryGranted = await ensureTelemetryPermissions();
    final notificationsGranted =
        await NotificationService.ensureNotificationPermission();

    return OnboardingPermissionResult(
      telemetryGranted: telemetryGranted,
      notificationsGranted: notificationsGranted,
    );
  }

  static Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  static Future<void> openExactAlarmSettingsOptional() async {
    await NotificationService.openExactAlarmSettingsOptional();
  }

  /// Only the low-friction, foundational permission requested in bulk
  /// during onboarding. Microphone and activity-recognition used to be
  /// bundled in here too, but asking for them before the user has even
  /// reached a screen that explains why (breath test, step tracking) hurt
  /// onboarding conversion and gave no context for the prompt — see
  /// [ensureMicrophonePermission] and [ensureActivityRecognitionPermission],
  /// requested contextually instead, right where each is actually used.
  static Future<bool> ensureTelemetryPermissions() async {
    try {
      // Used only to keep task notifications and the mandatory task gate
      // from interrupting a real phone call (see
      // DevicePermissionService.isInPhoneCall) — never to read numbers or
      // call content. Not surfaced as a failure: denying this doesn't
      // degrade a core feature, it just means the collision check silently
      // no-ops.
      await Permission.phone.request();
    } catch (_) {
      // Some platforms do not expose this permission.
    }

    return true;
  }

  /// Requested right before the first breath-test attempt starts (see
  /// BreathTestPage), not during onboarding — that's the first moment the
  /// user has actually seen why the app wants the microphone. A denial
  /// just means acoustic exhale detection stays off; the manual tap-to-
  /// finish flow still works exactly as before.
  static Future<bool> ensureMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Requested the first time step-based tracking actually needs it (see
  /// StepTrackingService), not during onboarding — activity recognition is
  /// a body-sensor-adjacent permission that reads as invasive out of
  /// context. A denial just means step-based signals stay unavailable;
  /// nothing else in the app depends on it.
  static Future<bool> ensureActivityRecognitionPermission() async {
    try {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}
