import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/breath_acoustic_sample.dart';
import 'package:no_smoke/models/noise_check_result.dart';
import 'package:no_smoke/services/breath_noise_check_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_noise_test').path;
  }
}

List<BreathAcousticSample> _samples(List<double> energies) {
  return [
    for (var i = 0; i < energies.length; i++)
      BreathAcousticSample(millisecondsSinceStart: i * 100, rmsEnergy: energies[i]),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  late StorageService storageService;
  late BreathNoiseCheckService service;

  setUp(() async {
    storageService = StorageService();
    await storageService.closeDatabaseConnection();
    final path = await storageService.databaseFilePath();
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
    service = BreathNoiseCheckService(storageService: storageService);
  });

  test('evaluatePreTestSamples persists a new baseline reading', () async {
    final before = await storageService.loadRecentBreathNoiseBaselines();
    expect(before, isEmpty);

    await service.evaluatePreTestSamples(_samples([0.01, 0.011, 0.009]));

    final after = await storageService.loadRecentBreathNoiseBaselines();
    expect(after.length, 1);
  });

  test('reference level adapts after repeated quiet baselines — a later '
      'moderately loud reading against a well-established quiet reference '
      'is flagged', () async {
    // Establish 10 quiet baselines first (the device "learns" a quiet
    // room).
    for (var i = 0; i < 10; i++) {
      await service.evaluatePreTestSamples(
        _samples([0.009, 0.01, 0.011, 0.01, 0.009]),
      );
    }

    // Now a reading at ~4x that reference should come back loud.
    final result = await service.evaluatePreTestSamples(
      _samples([0.04, 0.041, 0.039, 0.04, 0.041]),
    );

    expect(result.level, NoiseLevel.loud);
    expect(result.shouldMarkRecordAsNoisy, isTrue);
  });

  test('first-ever check (no baseline history) uses the default reference '
      'rather than crashing or always flagging noisy', () async {
    final result = await service.evaluatePreTestSamples(
      _samples([0.01, 0.011, 0.009, 0.01, 0.011]),
    );
    expect(result.level, NoiseLevel.quiet);
  });

  test('evaluateDuringAttempt does not persist a new baseline', () async {
    await service.evaluatePreTestSamples(_samples([0.01, 0.011, 0.009]));
    final afterPreTest = await storageService.loadRecentBreathNoiseBaselines();
    expect(afterPreTest.length, 1);

    await service.evaluateDuringAttempt(_samples([0.09, 0.091, 0.089]));
    final afterDuringAttempt =
        await storageService.loadRecentBreathNoiseBaselines();
    // Still just the one from the pre-test check — the mid-attempt check
    // must not add a second baseline entry.
    expect(afterDuringAttempt.length, 1);
  });
}
