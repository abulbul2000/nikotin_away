import 'dart:async';

import '../engines/breath_noise_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../models/breath_noise_baseline.dart';
import '../models/noise_check_result.dart';
import 'storage_service.dart';

/// Wires [BreathNoiseEngine] (pure: threshold math) and [StorageService]
/// (I/O: persisting/reading the device's own baseline history) together.
///
/// Deliberately does not own a microphone session itself: [BreathTestPage]
/// already runs a single continuous [BreathAudioService] recording for the
/// whole attempt (sit-relax through exhale) — a second concurrent
/// `startListening` call would tear that down. Callers pass in whatever
/// window of already-collected samples they want evaluated (the quiet
/// sit-relax stretch before an attempt, or the pre-exhale hold window
/// during one) and this only does the evaluate-and-optionally-persist part.
class BreathNoiseCheckService {
  final BreathNoiseEngine _noiseEngine;
  final StorageService _storageService;

  BreathNoiseCheckService({
    BreathNoiseEngine? noiseEngine,
    StorageService? storageService,
  }) : _noiseEngine = noiseEngine ?? BreathNoiseEngine(),
       _storageService = storageService ?? StorageService();

  /// Evaluates the ambient window collected before an attempt starts (the
  /// 2-3s the product spec asks for) against this device's own reference
  /// level, then persists the reading as a new [BreathNoiseBaseline] so
  /// future reference levels keep adapting to this device/room — including
  /// readings that turned out warning/loud, since a single noisy reading is
  /// still real information and [BreathNoiseEngine.computeReferenceLevel]'s
  /// median-of-recent approach already guards against any one outlier.
  Future<NoiseCheckResult> evaluatePreTestSamples(
    List<BreathAcousticSample> ambientSamples,
  ) async {
    final result = await _evaluate(ambientSamples);
    await _storageService.saveBreathNoiseBaseline(
      BreathNoiseBaseline(
        measuredAt: DateTime.now(),
        level: result.measuredLevel,
      ),
    );
    return result;
  }

  /// Evaluates an already-collected window of samples (e.g. the quiet
  /// stretch right before an attempt's exhale) against the current device
  /// reference — used for the mid-attempt "did someone start talking"
  /// check. Does not persist a new baseline: an in-attempt window is more
  /// likely to be contaminated by the test itself (breathing, shifting)
  /// than the dedicated pre-test window, so it shouldn't feed back into the
  /// device's calibration.
  Future<NoiseCheckResult> evaluateDuringAttempt(
    List<BreathAcousticSample> preExhaleSamples,
  ) async {
    final referenceLevel = await _referenceLevel();
    return _noiseEngine.evaluateDuringAttempt(
      preExhaleSamples,
      referenceLevel: referenceLevel,
    );
  }

  Future<NoiseCheckResult> _evaluate(List<BreathAcousticSample> samples) async {
    final referenceLevel = await _referenceLevel();
    return _noiseEngine.evaluate(samples, referenceLevel: referenceLevel);
  }

  Future<double> _referenceLevel() async {
    final baselines = await _storageService.loadRecentBreathNoiseBaselines(
      limit: BreathNoiseEngine.referenceSampleCount,
    );
    return _noiseEngine.computeReferenceLevel(baselines);
  }
}
