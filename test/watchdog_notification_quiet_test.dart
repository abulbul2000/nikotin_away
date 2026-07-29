import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The watchdog runs as a foreground service, which Android requires to show
/// a notification for as long as it lives. The task alert (full-screen
/// intent) is the user-facing prompt; this notification exists only to keep
/// the OS from killing the response timer. The user reported it landing next
/// to the task alert as a second, differently-titled thing asking for
/// attention — this guards the fix staying in place.
void main() {
  final file = File(
    'android/app/src/main/kotlin/com/example/no_smoke/NoResponseWatchdogService.kt',
  );

  test('the watchdog notification is silent and minimum priority', () {
    final source = file.readAsStringSync();
    expect(source, contains('.setSilent(true)'));
    expect(source, contains('NotificationCompat.PRIORITY_MIN'));
    expect(source, contains('NotificationManager.IMPORTANCE_MIN'));
  });

  test('the watchdog notification is marked as a service, not an alert', () {
    final source = file.readAsStringSync();
    expect(source, contains('NotificationCompat.CATEGORY_SERVICE'));
  });

  test('the old alarming wording is gone from the notification text', () {
    final source = file.readAsStringSync();
    // Only the strings actually shown to the user, not code comments that
    // reference the old wording while explaining why it changed.
    final title = RegExp(r'setContentTitle\("([^"]*)"\)').firstMatch(source);
    final body = RegExp(r'setContentText\("([^"]*)"\)').firstMatch(source);
    expect(title, isNotNull);
    expect(body, isNotNull);
    // "Nikotin Away Watchdog" / "10 dakika yanit takibi aktif" read as a
    // second countdown competing with the task alert it exists to support.
    expect(title!.group(1), isNot(contains('Watchdog')));
    expect(body!.group(1), isNot(contains('10 dakika')));
  });
}
