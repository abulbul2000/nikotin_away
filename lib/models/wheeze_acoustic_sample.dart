/// One FFT analysis window's worth of frequency-domain findings — the
/// wheeze-detection counterpart to [BreathAcousticSample], which only ever
/// carries a single time-domain energy scalar.
///
/// Deliberately carries only two scalars and an optional peak-frequency
/// float derived from a single FFT window — never the FFT magnitude
/// spectrum itself, which is discarded the instant these are computed from
/// it (see WheezeDetectionEngine._analyzeWindow). Same "the raw signal
/// never survives past the moment a summary is derived from it" guarantee
/// breath_acoustic_sample.dart makes for rmsEnergy, just for the frequency
/// domain instead of the time domain.
class WheezeAcousticSample {
  final int millisecondsSinceStart;

  /// Energy in the wheeze band (100-1000 Hz) divided by this window's total
  /// spectral energy, 0..1.
  final double wheezeBandEnergyRatio;

  /// The frequency (Hz) of the most prominent peak within the wheeze band,
  /// or null when no single bin clearly dominates (broadband noise rather
  /// than a tonal peak) — see WheezeDetectionEngine's dominance check.
  final double? dominantFrequencyHz;

  /// Total spectral energy of the window, same normalization convention as
  /// [BreathAcousticSample.rmsEnergy] — used as a near-silence guard so a
  /// near-zero-energy window can't produce a misleadingly high ratio.
  final double totalEnergy;

  const WheezeAcousticSample({
    required this.millisecondsSinceStart,
    required this.wheezeBandEnergyRatio,
    required this.dominantFrequencyHz,
    required this.totalEnergy,
  });
}
