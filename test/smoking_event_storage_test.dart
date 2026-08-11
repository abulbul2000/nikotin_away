import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_smoking_event_test')
        .path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    final storage = StorageService();
    await storage.clearAllData();
  });

  test('logSmokingNow saves an exact, non-approximate event', () async {
    final storage = StorageService();
    await storage.logSmokingNow();

    final events = await storage.loadSmokingEvents();
    expect(events, hasLength(1));
    expect(events.first.source, 'quick_log');
    expect(events.first.approximate, isFalse);
  });

  test('logRecalledSmokingHours saves one approximate event per hour', () async {
    final storage = StorageService();
    final day = DateTime(2026, 7, 21);

    await storage.logRecalledSmokingHours(day: day, hours: [9, 14, 21]);

    final events = await storage.loadSmokingEventsForDay(day);
    expect(events, hasLength(3));
    expect(events.every((e) => e.source == 'daily_recall'), isTrue);
    expect(events.every((e) => e.approximate), isTrue);
    expect(events.map((e) => e.timestamp.hour).toList(), [9, 14, 21]);
  });

  test('loadSmokingEventsForDay only returns events from that calendar day', () async {
    final storage = StorageService();
    await storage.logRecalledSmokingHours(
      day: DateTime(2026, 7, 20),
      hours: [10],
    );
    await storage.logRecalledSmokingHours(
      day: DateTime(2026, 7, 21),
      hours: [11, 12],
    );

    final day21Events = await storage.loadSmokingEventsForDay(
      DateTime(2026, 7, 21),
    );
    expect(day21Events, hasLength(2));
  });

  test('loadSmokingEvents(since:) filters out older events', () async {
    final storage = StorageService();
    await storage.logRecalledSmokingHours(
      day: DateTime(2026, 7, 1),
      hours: [9],
    );
    await storage.logRecalledSmokingHours(
      day: DateTime(2026, 7, 21),
      hours: [9],
    );

    final recent = await storage.loadSmokingEvents(
      since: DateTime(2026, 7, 15),
    );
    expect(recent, hasLength(1));
    expect(recent.first.timestamp.month, 7);
    expect(recent.first.timestamp.day, 21);
  });

  group('quick log', () {
    test('keeps the moment the press happened, not when it was read', () async {
      final storage = StorageService();
      // The native button queues presses while no engine is alive, so the
      // timestamp has to survive the replay — otherwise every cigarette
      // logged on a locked phone would land at whenever the app next opened,
      // which is exactly the hour the risky-hour ranking must not learn.
      final pressedAt = DateTime(2026, 7, 22, 3, 40);

      await storage.logSmokingNow(timestamp: pressedAt);

      final events = await storage.loadSmokingEvents(
        since: DateTime(2026, 7, 22),
      );
      expect(events, hasLength(1));
      expect(events.first.timestamp, pressedAt);
      expect(events.first.source, 'quick_log');
      expect(events.first.approximate, isFalse);
    });

    test('stores a place id when one was resolved', () async {
      final storage = StorageService();

      await storage.logSmokingNow(
        timestamp: DateTime(2026, 7, 23, 14, 0),
        placeId: 'place_work',
      );

      final events = await storage.loadSmokingEvents(
        since: DateTime(2026, 7, 23),
      );
      expect(events.single.placeId, 'place_work');
    });

    test('records without a place when location was unavailable', () async {
      final storage = StorageService();

      // Location must never gate the record: no permission, no fix, or a
      // spot the user doesn't often visit all end here, and the cigarette
      // still has to be counted.
      await storage.logSmokingNow(timestamp: DateTime(2026, 7, 24, 9, 0));

      final events = await storage.loadSmokingEvents(
        since: DateTime(2026, 7, 24),
      );
      expect(events.single.placeId, isNull);
    });

    test('counts events since a cutoff, and reports absence as null', () async {
      final storage = StorageService();

      // null rather than 0: the weekly review treats "nothing logged" as no
      // evidence and falls back to task success, where 0 would read as a
      // flawless week and stretch the barrier for someone who had simply
      // stopped using the button.
      expect(
        await storage.countSmokingEventsSince(DateTime(2027, 1, 1)),
        isNull,
      );

      await storage.logSmokingNow(timestamp: DateTime(2027, 1, 2, 10, 0));
      await storage.logSmokingNow(timestamp: DateTime(2027, 1, 2, 12, 0));

      expect(await storage.countSmokingEventsSince(DateTime(2027, 1, 1)), 2);
    });

    test('logSmokingNow returns an id that undoes exactly that record',
        () async {
      // The lock-screen quick-log route is a single notification tap with
      // no hold-to-confirm — an accidental press has no guard until
      // NotificationService.showSmokedLogUndoPrompt offers this id back.
      final storage = StorageService();
      final keptId = await storage.logSmokingNow(
        timestamp: DateTime(2026, 8, 1, 9, 0),
      );
      final undoneId = await storage.logSmokingNow(
        timestamp: DateTime(2026, 8, 1, 10, 0),
      );

      await storage.deleteSmokingEvent(undoneId);

      final events = await storage.loadSmokingEvents(
        since: DateTime(2026, 8, 1),
      );
      expect(events, hasLength(1));
      expect(events.single.timestamp, DateTime(2026, 8, 1, 9, 0));
      // keptId's row is the one still there, not incidentally the only one.
      expect(keptId, isNot(undoneId));
    });

    test('deleting an id that was already removed is a safe no-op',
        () async {
      final storage = StorageService();
      final id = await storage.logSmokingNow(
        timestamp: DateTime(2026, 8, 2, 9, 0),
      );

      await storage.deleteSmokingEvent(id);
      await storage.deleteSmokingEvent(id);

      final events = await storage.loadSmokingEvents(
        since: DateTime(2026, 8, 2),
      );
      expect(events, isEmpty);
    });
  });

  group('pre-sleep routine discrepancy recall', () {
    test(
      'logRecalledSmokingHours closes the gap evaluateTodaySmokingDiscrepancy '
      'reported, the real caller in SleepRoutinePage',
      () async {
        final storage = StorageService();
        final now = DateTime.now();

        // Only 2 logged so far today, nothing to imply an average yet — the
        // discrepancy check falls back to loadSmokingWindowInput's default
        // (20/day) when no survey exists, so this exercises the same shape
        // the routine sees on a fresh install.
        await storage.logSmokingNow(
          timestamp: DateTime(now.year, now.month, now.day, 9),
        );
        await storage.logSmokingNow(
          timestamp: DateTime(now.year, now.month, now.day, 13),
        );

        final before = await storage.evaluateTodaySmokingDiscrepancy(
          now: now,
        );
        expect(before.loggedCount, 2);
        expect(before.hasDiscrepancy, isTrue);

        // The user answers the discrepancy question and picks the hours they
        // forgot — SleepRoutinePage's _SmokingDiscrepancyStep calls exactly
        // this with the gap-sized hour selection.
        await storage.logRecalledSmokingHours(
          day: now,
          hours: List<int>.generate(before.gap, (i) => 17 + i),
        );

        final after = await storage.evaluateTodaySmokingDiscrepancy(now: now);
        expect(after.loggedCount, before.loggedCount + before.gap);
        // Logging exactly the missing amount closes the gap to zero, below
        // the discrepancy threshold.
        expect(after.gap, 0);
        expect(after.hasDiscrepancy, isFalse);
      },
    );
  });
}
