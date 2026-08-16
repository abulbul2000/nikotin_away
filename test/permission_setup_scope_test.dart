import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The permission screen contains both required permissions and optional
/// feature permissions. Optional entries must not block completion of the
/// mandatory setup. Sleep Intelligence is intentionally enabled from this
/// flow because its permission row is also its opt-in control; the other
/// optional permission rows only request platform access and do not enable a
/// feature implicitly.
void main() {
  final file = File('lib/pages/permission_setup_page.dart');

  String source() => file.readAsStringSync();

  test('the optional permissions are marked as not required', () {
    final code = source();
    for (final title in [
      'permissionMicrophoneTitle',
      'permissionLocationTitle',
      'permissionActivityTitle',
      'permissionHealthTitle',
    ]) {
      final start = code.indexOf("titleKey: '$title'");
      expect(start, isNot(-1), reason: '$title is missing from the screen');
      final nextItemStart = code.indexOf('_PermissionItem(', start);
      final blockEnd = nextItemStart == -1 ? code.length : nextItemStart;
      final block = code.substring(start, blockEnd);
      expect(
        block,
        contains('required: false'),
        reason: '$title must not count toward the required set',
      );
    }
  });

  test('"everything granted" only counts required items', () {
    final code = source();
    expect(
      RegExp(r'_items\s*\.where\(\s*\(item\)\s*=>\s*item\.required\s*\)\s*\.every')
          .hasMatch(code),
      isTrue,
      reason: 'a plain _items.every(...) would fold optional items back in',
    );
  });

  test('optional permission rows have the intended enablement scope', () {
    final code = source();

    // Sleep Intelligence is the one optional row that intentionally enables
    // its feature from this onboarding permission flow.
    expect(code, contains('SleepIntelligenceService().enable()'));

    // The remaining platform permission rows must only request access. They
    // must not save a feature setting or invoke a feature service implicitly.
    expect(code, isNot(contains('saveSetting')));
    expect(code, contains('ph.Permission.microphone.request()'));
    expect(code, contains('ph.Permission.locationWhenInUse.request()'));
    expect(code, contains('ph.Permission.activityRecognition.request()'));
    expect(code, contains('HealthConnectService().requestPermissions()'));
  });
}
