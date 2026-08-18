import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/notification_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_barrier_resolution')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const watchdogChannel = MethodChannel('no_smoke/watchdog');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    tz.initializeTimeZones();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().clearAllData();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, null);
  });

  test('scheduleBarrierResolutionReminder fires later than, and under a '
      'different id than, the first confirmation prompt it repeats', () async {
    // Regression coverage: scheduleBarrierResolutionReminder used to be a
    // bare alias of scheduleTaskConfirmationPrompt, reusing the exact same
    // notification id and the exact same delay. Since a fixed-id schedule
    // call replaces any earlier alarm under that id, the "quieter repeat"
    // this function is documented to be (see the call site in
    // task_assignment_service.dart) was actually just re-scheduling the
    // identical alarm at the identical instant — a silent no-op that left
    // barrier acceptance with no real second nudge if the first prompt
    // went unanswered.
    final scheduled = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'zonedSchedule') {
            scheduled.add(Map<String, dynamic>.from(call.arguments as Map));
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, (call) async => null);

    const taskTitle = 'Yürüyüşe çık';
    const delay = Duration(minutes: 30);

    await NotificationService.scheduleTaskConfirmationPrompt(
      taskTitle: taskTitle,
      delay: delay,
    );
    await NotificationService.scheduleBarrierResolutionReminder(
      taskTitle: taskTitle,
      delay: delay,
    );

    expect(scheduled.length, 2);
    final firstId = scheduled[0]['id'] as int;
    final secondId = scheduled[1]['id'] as int;
    expect(
      secondId,
      isNot(firstId),
      reason:
          'the reminder must not reuse the first prompt\'s notification '
          'id, or scheduling it replaces the first prompt instead of '
          'adding a second, later one',
    );

    final firstFireAt = DateTime.parse(
      scheduled[0]['scheduledDateTimeISO8601'] as String,
    );
    final secondFireAt = DateTime.parse(
      scheduled[1]['scheduledDateTimeISO8601'] as String,
    );
    // Each call independently reads DateTime.now(), so a few hundred
    // milliseconds of real wall-clock drift between the two calls is
    // expected and not the thing under test.
    expect(
      secondFireAt.difference(firstFireAt).inSeconds,
      closeTo(NotificationService.barrierResolutionDeadline.inSeconds, 2),
      reason:
          'the reminder must fire barrierResolutionDeadline after the '
          'first prompt, matching StorageService.closeStaleAcceptedBarriers'
          "'s own cutoff math, not at the same instant as the first prompt",
    );
  });

  test('cancelBarrierResolutionReminder cancels both the reminder and the '
      'confirmation prompt it repeats', () async {
    final cancelledIds = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'cancel') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            cancelledIds.add(args['id'] as int);
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, (call) async => null);

    await NotificationService.cancelBarrierResolutionReminder('Yürüyüşe çık');

    expect(cancelledIds.length, 2);
    expect(cancelledIds.toSet().length, 2);
  });
}
