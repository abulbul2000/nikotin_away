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

  static Future<bool> ensureTelemetryPermissions() async {
    var granted = true;

    try {
      final activity = await Permission.activityRecognition.request();
      granted = granted && activity.isGranted;
    } catch (_) {
      // Some platforms do not expose this permission.
    }

    try {
      final microphone = await Permission.microphone.request();
      granted = granted && microphone.isGranted;
    } catch (_) {
      // Some platforms may deny or not expose this permission.
    }

    try {
      // Used only to keep the fake-call barrier from ringing over a real
      // phone call (see DevicePermissionService.isInPhoneCall) — never to
      // read numbers or call content. Not folded into `granted`: unlike the
      // other telemetry permissions, denying this doesn't degrade a core
      // feature, it just means the collision check silently no-ops.
      await Permission.phone.request();
    } catch (_) {
      // Some platforms do not expose this permission.
    }

    return granted;
  }
}
