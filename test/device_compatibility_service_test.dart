import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/device_compatibility_service.dart';

void main() {
  group('DeviceCompatibilityService.isAggressiveManufacturerName', () {
    test('null or empty is not aggressive', () {
      expect(
        DeviceCompatibilityService.isAggressiveManufacturerName(null),
        isFalse,
      );
      expect(
        DeviceCompatibilityService.isAggressiveManufacturerName(''),
        isFalse,
      );
    });

    test('known aggressive manufacturers match case-insensitively', () {
      for (final name in [
        'Xiaomi',
        'HUAWEI',
        'honor',
        'Oppo',
        'vivo',
        'OnePlus',
        'samsung',
        'Meizu',
        'ASUS',
      ]) {
        expect(
          DeviceCompatibilityService.isAggressiveManufacturerName(name),
          isTrue,
          reason: '$name should be flagged as aggressive',
        );
      }
    });

    test('unknown manufacturers are not flagged', () {
      expect(
        DeviceCompatibilityService.isAggressiveManufacturerName('Google'),
        isFalse,
      );
      expect(
        DeviceCompatibilityService.isAggressiveManufacturerName('Sony'),
        isFalse,
      );
    });
  });
}
