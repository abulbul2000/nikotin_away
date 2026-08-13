import 'dart:math';

import '../models/breath_acoustic_sample.dart';
import '../models/breath_noise_baseline.dart';
import '../models/noise_check_result.dart';

/// Ortam gürültüsünü, sabit bir dB eşiği yerine cihazın kendi geçmişine
/// göre göreli olarak değerlendirir — telefonlar arası mikrofon
/// hassasiyeti çok değiştiği için sabit bir eşik bazı cihazlarda hep
/// tetiklenir, bazılarında hiç tetiklenmez. Pure ve DB-free, diğer
/// engine'ler gibi — geçmiş baseline'ların okunup yazılması bir üst
/// katmanın (StorageService) işi.
class BreathNoiseEngine {
  // Referans, son bu kadar baseline ölçümünün medyanından hesaplanır.
  static const int referenceSampleCount = 10;

  // Yeterli geçmiş yokken (ilk birkaç test) kullanılan makul varsayılan —
  // BreathAcousticEngine._minBaseline'dan (0.002) belirgin şekilde yüksek,
  // tipik sessiz bir odanın normalize RMS enerjisine yakın.
  static const double defaultReferenceLevel = 0.01;

  static const double warningMultiplier = 2.0;
  static const double loudMultiplier = 4.0;

  /// Son [referenceSampleCount] baseline ölçümünün medyanı — cihazın kendi
  /// kalibrasyonu. Ortalama değil medyan: tek bir kapı çarpması gibi bir
  /// aykırı değer ortalamayı bozar, medyanı bozmaz. [allBaselines] herhangi
  /// bir sırada (ve herhangi bir uzunlukta) verilebilir; en yeni
  /// [referenceSampleCount] tanesi burada seçilir. Geçmiş boşsa
  /// [defaultReferenceLevel] döner.
  double computeReferenceLevel(List<BreathNoiseBaseline> allBaselines) {
    if (allBaselines.isEmpty) {
      return defaultReferenceLevel;
    }
    final sortedByRecency = [...allBaselines]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final levels =
        sortedByRecency.take(referenceSampleCount).map((b) => b.level).toList()
          ..sort();
    return _median(levels);
  }

  /// Test başlamadan önceki 2-3 saniyelik ortam dinleme penceresinden bir
  /// [NoiseCheckResult] üretir. [referenceLevel] genelde
  /// [computeReferenceLevel]'ın sonucudur.
  NoiseCheckResult evaluate(
    List<BreathAcousticSample> ambientSamples, {
    required double referenceLevel,
  }) {
    if (ambientSamples.isEmpty) {
      return NoiseCheckResult(
        measuredLevel: 0,
        volatility: 0,
        referenceLevel: referenceLevel,
        level: NoiseLevel.quiet,
      );
    }

    final energies = ambientSamples.map((s) => s.rmsEnergy).toList()..sort();
    final measuredLevel = _median(energies);
    final volatility = _standardDeviation(energies);

    return NoiseCheckResult(
      measuredLevel: measuredLevel,
      volatility: volatility,
      referenceLevel: referenceLevel,
      level: _resolveLevel(measuredLevel, referenceLevel),
    );
  }

  /// Test sırasında, üfleme başlamadan önceki sessiz pencerede seviyenin
  /// aniden yükselip yükselmediğini kontrol eder (ör. test ortasında biri
  /// konuşmaya başladı). [evaluate] ile aynı mantığı kullanır — ayrı bir
  /// metot olması sadece çağıranların niyetini netleştirmek için.
  NoiseCheckResult evaluateDuringAttempt(
    List<BreathAcousticSample> preExhaleSamples, {
    required double referenceLevel,
  }) {
    return evaluate(preExhaleSamples, referenceLevel: referenceLevel);
  }

  NoiseLevel _resolveLevel(double measuredLevel, double referenceLevel) {
    final safeReference = max(referenceLevel, defaultReferenceLevel * 0.1);
    if (measuredLevel >= safeReference * loudMultiplier) {
      return NoiseLevel.loud;
    }
    if (measuredLevel >= safeReference * warningMultiplier) {
      return NoiseLevel.warning;
    }
    return NoiseLevel.quiet;
  }

  double _median(List<double> sortedValues) {
    final mid = sortedValues.length ~/ 2;
    if (sortedValues.length.isOdd) {
      return sortedValues[mid];
    }
    return (sortedValues[mid - 1] + sortedValues[mid]) / 2;
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }
}
