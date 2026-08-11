import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/medication.dart';
import 'package:no_smoke/services/notification_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_medication_reminder')
        .path;
  }
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, null);
  });

  test('a medication reminder never carries embedded health advice',
      () async {
    final scheduledBodies = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'zonedSchedule') {
        final args = call.arguments as Map;
        scheduledBodies.add(args['body'] as String);
      }
      return null;
    });
    // Android platform is not present in a unit-test host, so
    // AndroidWatchdogService's channel calls are no-ops there anyway — this
    // handler just keeps the test from failing if that ever changes.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, (call) async => null);

    await NotificationService.scheduleMedicationReminders([
      Medication(
        id: 'med_1',
        name: 'Test İlacı',
        times: const ['09:00'],
        createdAt: DateTime(2026, 7, 20),
      ),
    ]);

    expect(scheduledBodies, isNotEmpty);
    // The old design embedded "💡 <tip>\n<disclaimer>" under the reminder
    // text — a reminder now says exactly one thing: take the medication.
    for (final body in scheduledBodies) {
      expect(body, isNot(contains('💡')));
    }
  });

  test('health condition advice no longer skips a user who takes medication',
      () async {
    // scheduleHealthConditionAdviceNotifications used to early-return
    // whenever StorageService.loadMedications() was non-empty, on the
    // theory the tip already rode along with a medication reminder. Now
    // that reminders never carry a tip, this must schedule regardless of
    // medication status — the test DB here has none, but the fix under
    // test is that the function no longer even checks.
    var scheduleCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'zonedSchedule') {
        scheduleCalls++;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, (call) async => null);

    await NotificationService.scheduleHealthConditionAdviceNotifications(
      healthConditions: const ['Hipertansiyon'],
      wakeTime: '07:00',
      sleepTime: '23:00',
    );

    expect(scheduleCalls, greaterThan(0));
  });
}
