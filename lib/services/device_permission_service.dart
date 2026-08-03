import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

/// Bridges to MIUI-specific permission screens that have no standard
/// Android/permission_handler equivalent. Xiaomi/MIUI/HyperOS gate
/// "display pop-up windows while running in the background" and "show on
/// Lock screen" — required for the mandatory task screen's full-screen
/// alert to actually take over a locked screen — behind their own
/// permission editor, which [openPermissionEditor] deep-links into
/// directly. No-ops (returns false) on non-Android or non-MIUI devices.
class DevicePermissionService {
  static const MethodChannel _channel = MethodChannel(
    'no_smoke/device_permissions',
  );

  static bool get _isAndroid => Platform.isAndroid;

  static Future<bool> isMiuiDevice() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isMiuiDevice') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPermissionEditor() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('openMiuiPermissionEditor') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Coarse in-call/not-in-call state only (READ_PHONE_STATE) — used to keep
  /// task notifications and the mandatory task gate from interrupting a
  /// genuine phone call. Missing permission or a non-Android platform are
  /// both treated as "not in a call" rather than surfacing an error,
  /// matching how the app treats its other optional sensor permissions.
  static Future<bool> isInPhoneCall() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isInPhoneCall') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getManufacturer() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('getManufacturer');
    } catch (_) {
      return null;
    }
  }

  /// Deep-links to the manufacturer's autostart/protected-apps screen when
  /// one is known (Xiaomi, Huawei/Honor, Oppo, Vivo, OnePlus, Samsung,
  /// Meizu, Asus); otherwise falls back to the generic per-app settings
  /// screen (`openAppSettings`, a universal Android intent present on every
  /// device) so every manufacturer — not just the ones with a known deep
  /// link — ends up with a usable button. This isn't specific to any one
  /// app feature: it's what makes every AlarmManager-driven background
  /// trigger in the app (sleep/location/step probes, scheduled reminders,
  /// any future alarm-style intervention) actually fire reliably instead of
  /// being silently killed by OEM battery management.
  static Future<bool> openAutostartSettings() async {
    if (_isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openAutostartSettings',
        );
        if (opened == true) {
          return true;
        }
      } catch (_) {
        // Fall through to the generic settings screen below.
      }
    }
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// "Display over other apps" -- lets the mandatory task screen cover
  /// whatever app is in the foreground, not just the lock screen. There is
  /// no runtime dialog for this permission; [requestOverlayPermission] sends
  /// the user straight to the dedicated Settings screen.
  static Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// "Usage access" -- lets the delivery gate see which app is in the
  /// foreground, so health-tip and task overlays skip a moment when the user
  /// is on a call, watching a video, playing a game or on social media
  /// instead of interrupting it. Optional: without it the app still falls
  /// back to its permission-free heuristics (Do Not Disturb, in-call state,
  /// landscape+audio immersion).
  static Future<bool> hasUsageAccessPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccessPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestUsageAccessPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel
              .invokeMethod<bool>('requestUsageAccessPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
