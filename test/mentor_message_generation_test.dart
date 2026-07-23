import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_mentor_generation_test')
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

  test('generateDailyMentorMessage persists a daily message', () async {
    final storage = StorageService();

    final message = await storage.generateDailyMentorMessage();

    expect(message.type, 'daily');
    final latest = await storage.loadLatestMentorMessage();
    expect(latest?.id, message.id);
  });

  test('generateWeeklyMentorMessage persists a weekly message', () async {
    final storage = StorageService();

    final message = await storage.generateWeeklyMentorMessage();

    expect(message.type, 'weekly');
    final latest = await storage.loadLatestMentorMessage();
    expect(latest?.id, message.id);
  });

  test('generateDailyMentorMessage includes a historical note once enough smoking-event history exists', () async {
    final storage = StorageService();
    final now = DateTime(2026, 7, 21); // a Tuesday
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekEveningDay = startOfThisWeek.subtract(const Duration(days: 3));

    // Log several evening cigarettes last week to establish a pattern.
    await storage.logRecalledSmokingHours(
      day: lastWeekEveningDay,
      hours: [19, 20, 21],
    );
    await storage.logRecalledSmokingHours(
      day: lastWeekEveningDay.add(const Duration(days: 1)),
      hours: [20],
    );

    final message = await storage.generateDailyMentorMessage(now: now);

    expect(message.text, contains('akşamları'));
  });
}
