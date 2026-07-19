import 'dart:async';
import 'dart:math';

import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sensor_service.dart';

/// Collects coarse ambient audio telemetry and converts it to lightweight
/// context signals for risk prediction. It does not perform speech recording.
class AmbientAudioService {
  static final AmbientAudioService _instance = AmbientAudioService._internal();

  factory AmbientAudioService() => _instance;

  AmbientAudioService._internal();

  final NoiseMeter _noiseMeter = NoiseMeter();
  final SensorService _sensorService = SensorService();

  StreamSubscription<NoiseReading>? _subscription;
  DateTime? _windowStartedAt;
  final List<double> _windowMeans = <double>[];
  double _windowPeak = 0;

  static const Duration _persistWindow = Duration(minutes: 20);

  bool get isMonitoring => _subscription != null;

  Future<bool> startMonitoring({bool requestPermission = false}) async {
    if (_subscription != null) {
      return true;
    }

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted && requestPermission) {
      micStatus = await Permission.microphone.request();
    }
    if (!micStatus.isGranted) {
      return false;
    }

    _windowStartedAt = DateTime.now();
    _subscription = _noiseMeter.noise.listen(
      _onNoiseReading,
      onError: (_) {
        _resetWindow();
      },
      cancelOnError: false,
    );
    return true;
  }

  Future<void> stopMonitoring() async {
    await _subscription?.cancel();
    _subscription = null;
    _resetWindow();
  }

  Future<void> _onNoiseReading(NoiseReading reading) async {
    final meanDb = reading.meanDecibel;
    final peakDb = reading.maxDecibel;

    if (!meanDb.isFinite || !peakDb.isFinite) {
      return;
    }

    _windowMeans.add(meanDb);
    _windowPeak = max(_windowPeak, peakDb);

    final startedAt = _windowStartedAt ?? DateTime.now();
    if (DateTime.now().difference(startedAt) < _persistWindow) {
      return;
    }

    final double averageMean = _windowMeans.isEmpty
      ? 0.0
      : _windowMeans.reduce((a, b) => a + b) / _windowMeans.length;
    final mealLikelihood = _estimateMealSoundLikelihood(
      meanDb: averageMean,
      peakDb: _windowPeak,
      stdDevDb: _stdDev(_windowMeans),
    );

    await _sensorService.logAmbientSample(
      ambientMeanDecibel: averageMean,
      ambientPeakDecibel: _windowPeak,
      mealSoundLikelihood: mealLikelihood.toDouble(),
    );

    _resetWindow();
    _windowStartedAt = DateTime.now();
  }

  void _resetWindow() {
    _windowStartedAt = null;
    _windowMeans.clear();
    _windowPeak = 0;
  }

  double _estimateMealSoundLikelihood({
    required double meanDb,
    required double peakDb,
    required double stdDevDb,
  }) {
    // Heuristic proxy for meal-like context (plate/cutlery noise profile).
    final meanSignal = ((meanDb - 45) / 20).clamp(0, 1);
    final peakSignal = ((peakDb - 60) / 18).clamp(0, 1);
    final varianceSignal = (stdDevDb / 10).clamp(0, 1);

    final score = meanSignal * 0.40 + peakSignal * 0.40 + varianceSignal * 0.20;
    return score.clamp(0, 1).toDouble();
  }

  double _stdDev(List<double> values) {
    if (values.length < 2) {
      return 0;
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((value) => pow(value - mean, 2).toDouble()).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }
}
