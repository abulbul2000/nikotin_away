import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_fake_call_test')
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

  test('loadFakeCallerName defaults to a placeholder when unset', () async {
    final storage = StorageService();
    expect(await storage.loadFakeCallerName(), isNotEmpty);
  });

  test('saveFakeCallerName persists a custom name', () async {
    final storage = StorageService();
    await storage.saveFakeCallerName('Deniz');
    expect(await storage.loadFakeCallerName(), 'Deniz');
  });

  test('barrier duration starts at 20 minutes and grows with success streak', () async {
    final storage = StorageService();
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 20);

    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 30);

    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 40);
  });

  test('a failed outcome resets the duration back to the 20-minute base', () async {
    final storage = StorageService();
    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 40);

    await storage.recordFakeCallBarrierOutcome(succeeded: false);
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 20);
  });

  test('barrier duration is capped at 90 minutes', () async {
    final storage = StorageService();
    for (var i = 0; i < 20; i++) {
      await storage.recordFakeCallBarrierOutcome(succeeded: true);
    }
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 90);
  });

  test('a worsening breath trend eases the duration back by 10 minutes', () async {
    final storage = StorageService();
    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 30);

    await storage.saveBreathTrendToday('worsening');
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 20);
  });

  test('a worsening breath trend never drops the duration below the 20-minute base', () async {
    final storage = StorageService();
    await storage.saveBreathTrendToday('worsening');
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 20);
  });

  test('an improving or stable breath trend does not change the duration', () async {
    final storage = StorageService();
    await storage.recordFakeCallBarrierOutcome(succeeded: true);
    await storage.saveBreathTrendToday('improving');
    expect(await storage.loadFakeCallBarrierDurationMinutes(), 30);
  });

  test('startFakeCallBarrier persists an end time in the future', () async {
    final storage = StorageService();
    final now = DateTime(2026, 7, 21, 12, 0);
    await storage.startFakeCallBarrier(now: now);

    final endsAt = await storage.loadFakeCallBarrierEndsAt();
    expect(endsAt, isNotNull);
    expect(endsAt!.isAfter(now), isTrue);
  });

  test('clearFakeCallBarrier removes the end time', () async {
    final storage = StorageService();
    await storage.startFakeCallBarrier();
    expect(await storage.loadFakeCallBarrierEndsAt(), isNotNull);

    await storage.clearFakeCallBarrier();
    expect(await storage.loadFakeCallBarrierEndsAt(), isNull);
  });

  test('incrementFakeCallAvoidanceStreak counts up and resets independently', () async {
    final storage = StorageService();
    expect(await storage.incrementFakeCallAvoidanceStreak(), 1);
    expect(await storage.incrementFakeCallAvoidanceStreak(), 2);
    await storage.resetFakeCallAvoidanceStreak();
    expect(await storage.incrementFakeCallAvoidanceStreak(), 1);
  });

  test('starting a barrier resets the avoidance streak', () async {
    final storage = StorageService();
    await storage.incrementFakeCallAvoidanceStreak();
    await storage.incrementFakeCallAvoidanceStreak();

    await storage.startFakeCallBarrier();

    expect(await storage.incrementFakeCallAvoidanceStreak(), 1);
  });
}
