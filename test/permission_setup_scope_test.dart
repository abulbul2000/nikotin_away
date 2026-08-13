import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The permission screen used to show only notifications and overlay — the
/// permissions optional features need (microphone, location, activity
/// recognition, Health Connect) were each requested only when the user
/// switched that feature on, in whatever screen owned the toggle. The user
/// described this as scattered. These checks hold the two things that made
/// consolidating them safe: the optional permissions must never count toward
/// "everything is granted", and granting one must never flip a feature on by
/// itself — that decision still belongs to the toggle in Settings.
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
      code,
      contains('_items\n      .where((item) => item.required)'),
      reason: 'a plain _items.every(...) would fold optional items back in',
    );
  });

  test(
    'granting an optional permission never writes a feature-enabled setting',
    () {
      final code = source();
      // saveSetting only ever appears in the location intelligence service's
      // own enable() flow, never here — this file must call the bare
      // permission_handler request, not a service method that also flips a
      // feature switch.
      expect(code, isNot(contains('saveSetting')));
      expect(code, isNot(contains('.enable()')));
    },
  );
}
