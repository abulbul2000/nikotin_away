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
}
