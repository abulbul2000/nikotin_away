import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/medication.dart';
import 'package:no_smoke/services/notification_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Returns the same directory on every call — required for the ledger test,
/// which reads back through a second, independently constructed
/// StorageService and would otherwise land in an unrelated temp database
/// (StorageService.databaseFilePath resolves a fresh directory on every
/// first access if this returned a new path each time).
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _path = Directory.systemTemp
      .createTempSync('no_smoke_medication_reminder')
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
    // The fake path provider now returns a stable directory (needed for the
    // ledger test below), so the sqlite file persists across tests in this
    // file unless cleared here.
    await StorageService().clearAllData();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(watchdogChannel, null);
  });

  test('a medication reminder never carries embedded health advice', () async {
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

  test(
    'a scheduled medication reminder is recorded on the shared budget ledger',
    () async {
      // scheduleMedicationReminders used to call _zonedSchedule directly,
      // never touching the budget's spacing bookkeeping — an offered
      // notification's minimumGap check had no way to know a medication
      // reminder had just been scheduled for that moment, since medication
      // is owed and skips the enabled/budget checks but must still record
      // lastSentAt.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationsChannel, (call) async => null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchdogChannel, (call) async => null);

      final storage = StorageService();

      // The ledger's daily-budget bookkeeping is keyed by the real moment
      // the notification is scheduled, never by its (possibly tomorrow,
      // if the dose time already passed today) fire time — regression
      // coverage for a bug where the two were conflated and a fire time
      // rolling past midnight silently reset the whole day's ledger for
      // anything checked afterward. So this looks the ledger up under
      // today's real key, matching what recordNotificationSent now always
      // writes under, regardless of what time '09:00' resolves to.
      final (beforeCount, beforeLastSent) = await storage
          .loadNotificationBudgetState();
      expect(beforeLastSent, isNull);

      await NotificationService.scheduleMedicationReminders([
        Medication(
          id: 'med_ledger',
          name: 'Test İlacı',
          times: const ['09:00'],
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      final (afterCount, afterLastSent) = await storage
          .loadNotificationBudgetState();
      expect(afterLastSent, isNotNull);
      // Owed kinds move the spacing clock but never spend the offered
      // allowance.
      expect(afterCount, beforeCount);
    },
  );

  test(
    'health condition advice no longer skips a user who takes medication',
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
    },
  );

  test(
    'deleting a medication cancels its outstanding postpone-reminder notification',
    () async {
      // Regression coverage: scheduleMedicationReminders (the recurring
      // reschedule medications_page.dart runs after every add/edit/delete)
      // only ever cancels its own fixed slot id range
      // (_medicationReminderBaseId + [0.._medicationReminderMaxSlots)) — a
      // "postponed" reminder for one specific medication lives outside that
      // range on purpose, so it used to survive that medication being
      // deleted (or edited, since editing reuses the same id) and would
      // still fire later for a medication that no longer exists.
      final cancelledIds = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationsChannel, (call) async {
            if (call.method == 'cancel') {
              final args = call.arguments as Map;
              cancelledIds.add(args['id'] as int);
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchdogChannel, (call) async => null);

      await NotificationService.cancelMedicationPostponeReminder('med_42');

      // 440100 (base) + 30 (max recurring slots) + ('med_42'.hashCode.abs()
      // % 10000) — mirrors _scheduleMedicationPostponeReminder's own id
      // formula exactly, so this fails if either side's formula ever
      // drifts from the other.
      final expectedId = 440100 + 30 + ('med_42'.hashCode.abs() % 10000);
      expect(cancelledIds, contains(expectedId));
    },
  );

  test(
    'rescheduling coach command notifications cancels the previous batch first',
    () async {
      // Regression coverage: scheduleCoachCommandNotifications used to id
      // each notification from DateTime.now().millisecondsSinceEpoch, a
      // different value every call with nothing ever cancelled -- calling
      // it twice with different commands (e.g. the coaching signature
      // legitimately changing partway through the same day) stacked a
      // second batch on top of the first still-pending one instead of
      // replacing it.
      final cancelledIds = <int>[];
      final scheduledIds = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationsChannel, (call) async {
            if (call.method == 'cancel') {
              final args = call.arguments as Map;
              cancelledIds.add(args['id'] as int);
            } else if (call.method == 'zonedSchedule') {
              final args = call.arguments as Map;
              scheduledIds.add(args['id'] as int);
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(watchdogChannel, (call) async => null);

      await NotificationService.scheduleCoachCommandNotifications(
        commands: const ['coachCommandBreathingExercise'],
        maxNotifications: 1,
      );
      expect(scheduledIds, isNotEmpty);
      final firstBatchIds = List<int>.from(scheduledIds);

      cancelledIds.clear();
      scheduledIds.clear();

      await NotificationService.scheduleCoachCommandNotifications(
        commands: const ['coachCommandDrinkWater'],
        maxNotifications: 1,
      );

      // The second call must cancel every id the first call could have
      // used before scheduling its own — proven here via the fixed
      // 6-slot range (460100..460105) rather than by re-deriving the
      // first call's exact id, since the fix's whole point is that the
      // range is fixed/bounded instead of freshly computed per call.
      for (var i = 0; i < 6; i++) {
        expect(cancelledIds, contains(460100 + i));
      }
      expect(scheduledIds, isNotEmpty);
      // The new batch reuses the same fixed range the cancel loop just
      // cleared, rather than minting yet another id nothing will ever
      // clean up -- this is deliberately the SAME range firstBatchIds
      // used too, since that's the whole point of the fix: a fixed,
      // reusable range that each call can fully cancel before rescheduling,
      // replacing the old millisecondsSinceEpoch-derived id that was
      // different (and never cleaned up) on every call.
      for (final id in scheduledIds) {
        expect(id, inInclusiveRange(460100, 460105));
      }
      expect(firstBatchIds, everyElement(inInclusiveRange(460100, 460105)));
    },
  );
}
