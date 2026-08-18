import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/smoking_event.dart';
import 'package:no_smoke/services/savings_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_savings_test').path;
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
    SharedPreferences.setMockInitialValues({});
    await StorageService().clearAllData();
  });

  test(
    'with no evidence yet, savings are all zero rather than a full-abstinence guess',
    () async {
      // Regression coverage for the bug this replaced: computeSavings used
      // to assume the user smoked zero cigarettes on every day since
      // quitDate, which is wrong for a gradual-reduction product (see
      // CLAUDE.md) — a user who cut down, not quit outright, would still
      // see inflated totals. With no logged evidence at all, the honest
      // answer is zero, same as ReductionProgress's own "no evidence"
      // case, not a days-times-baseline guess.
      final service = SavingsService(storageService: StorageService());
      final snapshot = await service.computeSavings();

      expect(snapshot.cigarettesNotSmoked, 0);
      expect(snapshot.moneySaved, 0);
      expect(snapshot.lifeTimeRegained, Duration.zero);
    },
  );

  test(
    'reflects actual logged reduction, not a full-abstinence assumption',
    () async {
      // computeSavings() takes no `now` override (it always uses the real
      // current moment, matching production), so this seeds data against
      // real DateTime.now() too rather than an arbitrary fixed date —
      // otherwise the logged events would fall outside
      // loadReductionProgress's day-by-day window relative to whatever
      // "now" it actually resolves internally.
      final storage = StorageService();
      final today = DateTime.now();

      // Baseline (from the default 20/day used when no survey exists —
      // see StorageService.loadSmokingWindowInput) is 20 cigarettes/day.
      // Logging 15 today means 5 avoided that day, not 20.
      for (var i = 0; i < 15; i++) {
        await storage.saveSmokingEvent(
          SmokingEvent(
            id: 'e-$i',
            timestamp: DateTime(
              today.year,
              today.month,
              today.day,
              1 + (i % 22),
            ),
            source: 'quick_log',
            approximate: false,
          ),
        );
      }

      final service = SavingsService(storageService: storage);
      await service.setPackPrice(100);
      final progress = await storage.loadReductionProgress();
      final snapshot = await service.computeSavings();

      expect(snapshot.cigarettesNotSmoked, progress.cigarettesAvoided);
      // Would be far more than this under the old days-since-quit *
      // packsPerDay formula for even a single day of data; must instead
      // match the real evidence-based figure (5, for this one day).
      expect(snapshot.cigarettesNotSmoked, lessThan(20));
    },
  );

  test(
    'money saved is proportional to cigarettes avoided and pack price',
    () async {
      final storage = StorageService();
      final service = SavingsService(storageService: storage);
      await service.setPackPrice(200);

      final snapshot = await service.computeSavings();
      final expectedPerCigarette = 200 / 20; // pack price / cigarettes per pack

      expect(
        snapshot.moneySaved,
        closeTo(snapshot.cigarettesNotSmoked * expectedPerCigarette, 0.001),
      );
    },
  );

  test('life time regained is 11 minutes per cigarette avoided', () async {
    final storage = StorageService();
    final today = DateTime.now();
    await storage.saveSmokingEvent(
      SmokingEvent(
        id: 'e1',
        timestamp: DateTime(today.year, today.month, today.day, 9),
        source: 'quick_log',
        approximate: false,
      ),
    );

    final service = SavingsService(storageService: storage);
    final progress = await storage.loadReductionProgress();
    final snapshot = await service.computeSavings();

    expect(
      snapshot.lifeTimeRegained,
      Duration(minutes: progress.cigarettesAvoided * 11),
    );
  });

  test('pack price defaults, then persists after being set', () async {
    final service = SavingsService(storageService: StorageService());
    expect(await service.getPackPrice(), 80.0);

    await service.setPackPrice(150);
    expect(await service.getPackPrice(), 150.0);
  });
}
