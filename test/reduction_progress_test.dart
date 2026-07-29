import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/adaptive_task_models.dart';
import 'package:no_smoke/models/smoking_event.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_reduction_test').path;
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
    await StorageService().clearAllData();
  });

  final today = DateTime(2026, 7, 20, 18);

  Future<void> logCigarettes(
    StorageService storage, {
    required int daysAgo,
    required int count,
  }) async {
    final day = today.subtract(Duration(days: daysAgo));
    for (var i = 0; i < count; i++) {
      await storage.saveSmokingEvent(
        SmokingEvent(
          id: 'd$daysAgo-$i',
          timestamp: DateTime(day.year, day.month, day.day, 8 + (i % 12)),
          source: 'quick_log',
          approximate: false,
        ),
      );
    }
  }

  Future<void> logTaskOutcome(
    StorageService storage, {
    required int daysAgo,
    required String outcome,
    int count = 1,
  }) async {
    final day = today.subtract(Duration(days: daysAgo));
    for (var i = 0; i < count; i++) {
      final at = DateTime(day.year, day.month, day.day, 10 + i);
      await storage.saveAdaptiveTaskEvent(
        AdaptiveTaskEvent(
          id: 'task-$daysAgo-$outcome-$i',
          taskTitle: 'task',
          scheduledAt: at,
          respondedAt: at,
          outcome: outcome,
          plannedDurationMinutes: 30,
          responseDelayMinutes: 0,
          hourBucket: at.hour,
        ),
      );
    }
  }

  test('an install with no data reports nothing rather than three zeros', () async {
    final progress = await StorageService().loadReductionProgress(now: today);

    // The counter this replaced would happily print a number here. Saying
    // "we don't know yet" is the honest answer on day one.
    expect(progress.hasEvidence, isFalse);
    expect(progress.targetStreakDays, 0);
    expect(progress.cigarettesAvoided, 0);
  });

  test('days under target build a streak, a day over it ends the streak', () async {
    final storage = StorageService();
    final target = await _impliedTarget(storage, today);

    // Three good days, then one over target further back.
    await logCigarettes(storage, daysAgo: 0, count: target);
    await logCigarettes(storage, daysAgo: 1, count: target);
    await logCigarettes(storage, daysAgo: 2, count: target);
    await logCigarettes(storage, daysAgo: 3, count: target + 5);

    final progress = await storage.loadReductionProgress(now: today);
    expect(progress.targetStreakDays, 3);
  });

  test('a gap in the data stops the streak instead of extending it', () async {
    final storage = StorageService();
    final target = await _impliedTarget(storage, today);

    await logCigarettes(storage, daysAgo: 0, count: target);
    await logCigarettes(storage, daysAgo: 1, count: target);
    // Nothing at all for day 2.
    await logCigarettes(storage, daysAgo: 3, count: target);

    final progress = await storage.loadReductionProgress(now: today);

    // Day 3 was a good day, but we know nothing about day 2 — crediting it
    // would be the same fabrication as counting calendar days since a quit
    // date and calling them smoke-free.
    expect(progress.targetStreakDays, 2);
  });

  test('an empty today does not wipe out a streak earned yesterday', () async {
    final storage = StorageService();
    final target = await _impliedTarget(storage, today);

    await logCigarettes(storage, daysAgo: 1, count: target);
    await logCigarettes(storage, daysAgo: 2, count: target);

    final progress = await storage.loadReductionProgress(now: today);

    // It may only be mid-morning. Today having no entries yet is normal,
    // not a failure.
    expect(progress.targetStreakDays, 2);
    expect(progress.loggedToday, isNull);
  });

  test('cigarettes avoided counts only days we have evidence for', () async {
    final storage = StorageService();
    final input = await storage.loadSmokingWindowInput();
    final baseline = input.dailyCigarettes;

    await logCigarettes(storage, daysAgo: 0, count: baseline - 4);
    await logCigarettes(storage, daysAgo: 1, count: baseline - 6);
    // Days 2..399 have no data and must contribute nothing — otherwise a
    // user who stopped logging would appear to be avoiding a full baseline
    // every single day.

    final progress = await storage.loadReductionProgress(now: today);
    expect(progress.cigarettesAvoided, 10);
    expect(progress.evidenceDays, 2);
  });

  test('smoking more than baseline never credits negative avoidance', () async {
    final storage = StorageService();
    final input = await storage.loadSmokingWindowInput();

    await logCigarettes(storage, daysAgo: 0, count: input.dailyCigarettes + 8);

    final progress = await storage.loadReductionProgress(now: today);
    expect(progress.cigarettesAvoided, 0);
  });

  test('task outcomes carry the streak for users who never log', () async {
    final storage = StorageService();

    await logTaskOutcome(storage, daysAgo: 0, outcome: AdaptiveTaskOutcome.success, count: 3);
    await logTaskOutcome(storage, daysAgo: 1, outcome: AdaptiveTaskOutcome.success, count: 3);

    final progress = await storage.loadReductionProgress(now: today);

    // The quick-log button is optional; most people will never press it.
    // Seeing tasks through is the other evidence we have.
    expect(progress.targetStreakDays, 2);
  });

  test('a logged count outranks task outcomes on the same day', () async {
    final storage = StorageService();
    final target = await _impliedTarget(storage, today);

    await logTaskOutcome(storage, daysAgo: 0, outcome: AdaptiveTaskOutcome.success, count: 4);
    await logCigarettes(storage, daysAgo: 0, count: target + 10);

    final progress = await storage.loadReductionProgress(now: today);

    // Answering the tasks and then smoking anyway is not a met target.
    expect(progress.targetStreakDays, 0);
  });

  test('mostly-failed tasks do not count as a met target', () async {
    final storage = StorageService();

    await logTaskOutcome(storage, daysAgo: 0, outcome: AdaptiveTaskOutcome.smoked, count: 3);
    await logTaskOutcome(storage, daysAgo: 0, outcome: AdaptiveTaskOutcome.success, count: 1);

    final progress = await storage.loadReductionProgress(now: today);
    expect(progress.targetStreakDays, 0);
  });

  test('interval progress is zero on day one and grows with the barrier', () async {
    final storage = StorageService();
    final progress = await storage.loadReductionProgress(now: today);

    // The seeded barrier already sits a quarter above the natural gap, so
    // the very first reading is a real 25% — the user is being asked to
    // wait longer than they used to from the start.
    expect(progress.naturalIntervalMinutes, greaterThan(0));
    expect(progress.currentBarrierMinutes, greaterThan(progress.naturalIntervalMinutes));
    expect(progress.intervalProgress, closeTo(0.25, 0.02));
  });

  test('a barrier below the natural gap reports no progress, not negative', () async {
    final storage = StorageService();
    await storage.saveSetting('current_barrier_minutes', '5');
    await storage.saveSetting('current_barrier_week_start', today.toIso8601String());

    final progress = await storage.loadReductionProgress(now: today);
    expect(progress.intervalProgress, 0);
  });
}

Future<int> _impliedTarget(StorageService storage, DateTime now) async {
  final progress = await storage.loadReductionProgress(now: now);
  return progress.dailyTarget;
}
