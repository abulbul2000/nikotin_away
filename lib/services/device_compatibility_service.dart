import 'package:permission_handler/permission_handler.dart';

import 'device_permission_service.dart';

/// Phase 12: turns the device signals `DevicePermissionService` already
/// exposes (manufacturer, battery-exemption status) into an actual
/// decision — "is this specific device likely to kill this app's
/// background work" — instead of leaving them as passive facts only
/// surfaced as buttons in the Permissions Center. Used to trigger a
/// contextual battery-exemption prompt at the moment a background-reliant
/// feature (Sleep/Location Intelligence) is actually turned on, rather
/// than hoping the user separately finds their way to Settings.
class DeviceCompatibilityService {
  // Manufacturers with a documented known/best-effort autostart or
  // aggressive-battery-management screen — see
  // DevicePermissionService.openAutostartSettings for the deep-link list
  // this mirrors. Kept as a simple substring set rather than importing
  // native logic, since this only needs to answer "is it worth asking".
  static const _knownAggressiveManufacturers = <String>{
    'xiaomi',
    'huawei',
    'honor',
    'oppo',
    'vivo',
    'oneplus',
    'samsung',
    'meizu',
    'asus',
  };

  Future<bool> isKnownAggressiveManufacturer() async {
    final manufacturer = await DevicePermissionService.getManufacturer();
    return isAggressiveManufacturerName(manufacturer);
  }

  /// Pure matching rule, split out from [isKnownAggressiveManufacturer] so
  /// it's testable without a platform channel.
  static bool isAggressiveManufacturerName(String? manufacturer) {
    if (manufacturer == null || manufacturer.isEmpty) {
      return false;
    }
    final lower = manufacturer.toLowerCase();
    return _knownAggressiveManufacturers.any(lower.contains);
  }

  /// True only when both conditions that actually matter are true: the
  /// device is known to aggressively kill background work, AND the app
  /// hasn't already been exempted from battery optimization. A
  /// non-aggressive manufacturer or an already-granted exemption both mean
  /// there's nothing useful to prompt for.
  Future<bool> isBackgroundReliabilityAtRisk() async {
    if (!await isKnownAggressiveManufacturer()) {
      return false;
    }
    final status = await Permission.ignoreBatteryOptimizations.status;
    return !status.isGranted;
  }
}
