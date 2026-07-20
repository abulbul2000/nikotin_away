
import 'package:permission_handler/permission_handler.dart';

/// Provides location access utilities for the No Smoke app.
/// Location data is used to improve context-aware task scheduling
/// (e.g. detecting when the user is at home vs. commuting).
class LocationService {
  /// Returns true if location permission is currently granted.
  static Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.location.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current permission status as a string for logging/display.
  static Future<String> permissionStatusLabel() async {
    try {
      final status = await Permission.location.status;
      if (status.isGranted) return 'granted';
      if (status.isLimited) return 'limited';
      if (status.isDenied) return 'denied';
      if (status.isPermanentlyDenied) return 'permanently_denied';
      if (status.isRestricted) return 'restricted';
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}
