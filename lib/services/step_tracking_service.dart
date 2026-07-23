import 'package:permission_handler/permission_handler.dart';

import '../engines/step_trend_engine.dart';
import '../models/step_counter_sample.dart';
import 'step_counter_service.dart';
import 'storage_service.dart';

/// Orchestrates step tracking. Unlike Sleep/Location Intelligence this has
/// no separate opt-in toggle: it only ever runs once ACTIVITY_RECOGNITION
/// is already granted (requested during onboarding for ambient-sensor
/// inference), and reads nothing more sensitive than a step count, so the
/// existing Activity permission card in the Permissions Center is
/// sufficient disclosure rather than a whole extra consent flow.
class StepTrackingService {
  final StorageService _storageService;
  final StepTrendEngine _trendEngine;

  static const Duration _minSampleInterval = Duration(hours: 1);

  StepTrackingService({
    StorageService? storageService,
    StepTrendEngine? trendEngine,
  }) : _storageService = storageService ?? StorageService(),
       _trendEngine = trendEngine ?? StepTrendEngine();

  Future<void> ensureDailyProbeScheduled() async {
    if (!await Permission.activityRecognition.isGranted) {
      return;
    }
    await StepCounterService.scheduleDailyStepProbe();
  }

  Future<void> sampleCurrentStepsIfDue() async {
    if (!await Permission.activityRecognition.isGranted) {
      return;
    }

    final lastSampleRaw = await _storageService.loadSetting(
      'step_last_sample_at',
    );
    final lastSample = lastSampleRaw == null
        ? null
        : DateTime.tryParse(lastSampleRaw);
    if (lastSample != null &&
        DateTime.now().difference(lastSample) < _minSampleInterval) {
      return;
    }

    final steps = await StepCounterService.readCurrentStepCount();
    if (steps == null) {
      return;
    }

    final now = DateTime.now();
    await _storageService.saveSetting(
      'step_last_sample_at',
      now.toIso8601String(),
    );
    await _storageService.saveStepCounterSample(
      StepCounterSample(
        id: 'stepsample_dart_${now.microsecondsSinceEpoch}',
        createdAt: now,
        cumulativeSteps: steps,
      ),
    );
  }

  Future<int> totalStepsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final samples = await _storageService.loadStepCounterSamples(
      since: start.subtract(const Duration(days: 1)),
    );
    return _trendEngine.totalStepsInRange(samples, start: start, end: end);
  }
}
