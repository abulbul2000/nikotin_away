import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../models/wheeze_acoustic_sample.dart';

class WheezeAnalysis {
  /// Whether a sustained, narrow-band tone was found in the wheeze band
  /// (see [WheezeDetectionEngine.minConsecutiveWindowsForWheeze]).
  final bool wheezeDetected;

  /// 'none' | 'mild' | 'moderate' | 'severe'.
  final String severityLevel;

  /// 0-100, same shape as CoughTestAnalysis.severityScore.
  final int severityScore;

  /// Mean wheeze-band energy ratio across the longest streak, null when no
  /// wheeze was detected.
  final double? wheezeBandEnergyRatio;

  /// A representative dominant frequency from within the longest streak,
  /// null when no wheeze was detected.
  final double? dominantFrequencyHz;

  /// Duration of the longest continuous wheeze streak, null when no wheeze
  /// was detected.
  final int? wheezeDurationMs;

  const WheezeAnalysis({
    required this.wheezeDetected,
    required this.severityLevel,
    required this.severityScore,
    this.wheezeBandEnergyRatio,
    this.dominantFrequencyHz,
    this.wheezeDurationMs,
  });

  static const none = WheezeAnalysis(
    wheezeDetected: false,
    severityLevel: 'none',
    severityScore: 0,
  );
}

/// Detects sustained, narrow-band acoustic wheeze from a stream of raw PCM16
/// audio chunks — the frequency-domain counterpart to [BreathAcousticEngine]
/// (exhale timing) and [CoughAcousticEngine] (cough counting), both of which
/// are purely time-domain and cannot distinguish a tonal wheeze from any
/// other loud sound.
///
/// Pure rule-based DSP (short-window FFT + fixed frequency band + energy
/// ratio + narrow-peak continuity check), deliberately not machine learning
/// — matches the rest of this app's fully offline, deterministic,
/// explainable engines.
///
/// **Not device-calibrated.** The frequency band (100-1000 Hz), energy-ratio
/// threshold (0.35), and continuity window (320ms) are derived from
/// respiratory-acoustics literature and general DSP theory, not from real
/// wheeze recordings on real device hardware/microphone/AGC behavior — the
/// same caveat class as [BreathAcousticEngine] ("only verified against one
/// physical device") and [CoughAcousticEngine] ("a starting estimate, not
/// device-verified"). Should be revisited against real recordings (e.g. a
/// small set of known wheeze samples played back through a phone speaker)
/// before the thresholds are trusted clinically.
class WheezeDetectionEngine {
  /// FFT window size in samples. At the 16kHz sample rate BreathAudioService
  /// records at, this is 64ms/window — a good compromise: 16000/1024 ≈
  /// 15.6 Hz/bin gives enough frequency resolution to see a wheeze's narrow
  /// spectral peak (512 samples, 31.25 Hz/bin, is a bit coarse for that),
  /// while staying short enough that several independent windows still fit
  /// inside a single ~0.5-1s wheeze cycle for the continuity check below
  /// (2048 samples, 128ms, would smear transients more than necessary).
  static const int windowSizeSamples = 1024;
  static const double sampleRateHz = 16000;
  static const double windowDurationMs =
      windowSizeSamples / sampleRateHz * 1000;

  /// Wheeze band, per respiratory-sound literature (e.g. Sovijärvi et al.):
  /// a continuous, musical adventitious sound, typically >100 Hz, with
  /// higher-pitched wheezes extending toward 1000 Hz+.
  static const double wheezeBandMinHz = 100;
  static const double wheezeBandMaxHz = 1000;

  /// A window counts toward a wheeze streak once its in-band energy clears
  /// this fraction of the window's total energy — below this, in-band
  /// energy reads as a plausible fraction of a broadband breath/cough sound
  /// rather than a tonal wheeze riding on top of it. Deliberately on the
  /// sensitive side (see [BreathAcousticEngine.onsetMultiplier]'s doc
  /// comment for the same "unverified against real devices" reasoning).
  static const double wheezeRatioThreshold = 0.35;

  /// How close two consecutive in-streak dominant frequencies must stay to
  /// count as "the same tone" rather than unrelated broadband energy that
  /// happened to clear the ratio threshold on different sub-frequencies
  /// from one window to the next.
  static const double dominantFrequencyToleranceHz = 150;

  /// Minimum consecutive in-band windows for a genuine wheeze: 5 windows ×
  /// 64ms ≈ 320ms. Wheeze is clinically a *continuous* sound; 320ms is a
  /// conservative floor that also comfortably exceeds a single cough
  /// burst's ~150-350ms envelope (CoughAcousticEngine.minEventGapMs's doc
  /// comment), keeping the two engines' "events" from cross-contaminating.
  static const int minConsecutiveWindowsForWheeze = 5;

  /// Below this, a window's total energy is too close to silence for its
  /// ratio to be meaningful — mirrors CoughAcousticEngine's
  /// `max(medianEnergy, 0.002)` epsilon pattern.
  static const double _minTotalEnergy = 0.0005;

  /// A peak bin only counts as a genuine dominant frequency (as opposed to
  /// the loudest of many similar-sized bins in broadband noise) if it
  /// carries at least this fraction of the window's in-band energy.
  static const double _dominancePeakFraction = 0.30;

  /// Duration (seconds) at which a wheeze streak is scored as "fully
  /// sustained" for the duration component of severity.
  static const double _fullySustainedSeconds = 3.0;

  final FFT _fft = FFT(windowSizeSamples);
  final List<int> _pendingBytes = [];

  /// Clears any bytes carried over from a previous recording. Callers reuse
  /// one engine instance across multiple attempts in the same page session
  /// (BreathTestPage's multi-attempt flow); without this, leftover bytes
  /// from attempt N's tail — too few to complete a window on their own —
  /// would silently prepend themselves onto attempt N+1's first window,
  /// mixing audio across attempts.
  void reset() {
    _pendingBytes.clear();
  }

  /// Accumulates [rawChunk] into a rolling buffer and returns one
  /// [WheezeAcousticSample] per full [windowSizeSamples] window that
  /// completes, carrying any remainder under a window's worth over to the
  /// next call. Returns an empty list when no window has completed yet —
  /// `record`-package chunks don't arrive aligned to window boundaries, so
  /// most calls return empty.
  ///
  /// Returns a list rather than a single sample because [rawChunk] can
  /// complete more than one window in a single call (e.g. after a delivery
  /// delay, or if the audio plugin batches unevenly) — returning only the
  /// first and leaving the rest sitting in [_pendingBytes] until some later
  /// call happened to complete another window would silently drop or delay
  /// real audio data relative to when it was actually captured.
  ///
  /// The full FFT magnitude spectrum is discarded the instant the summary
  /// scalars are computed from it — see the class doc comment and
  /// [WheezeAcousticSample]'s doc comment for the privacy rationale this
  /// preserves.
  List<WheezeAcousticSample> pushChunk(
    Uint8List rawChunk,
    int millisecondsSinceStart,
  ) {
    _pendingBytes.addAll(rawChunk);
    const bytesPerWindow = windowSizeSamples * 2; // PCM16 = 2 bytes/sample.

    final samples = <WheezeAcousticSample>[];
    var windowTimestampMs = millisecondsSinceStart;
    while (_pendingBytes.length >= bytesPerWindow) {
      final windowBytes = Uint8List.fromList(
        _pendingBytes.sublist(0, bytesPerWindow),
      );
      _pendingBytes.removeRange(0, bytesPerWindow);
      samples.add(_analyzeWindow(windowBytes, windowTimestampMs));
      windowTimestampMs += windowDurationMs.round();
    }
    return samples;
  }

  WheezeAcousticSample _analyzeWindow(
    Uint8List windowBytes,
    int millisecondsSinceStart,
  ) {
    final byteData = ByteData.sublistView(windowBytes);
    final samples = List<double>.generate(windowSizeSamples, (i) {
      final raw = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      // Hann window — reduces spectral leakage (a strong low-frequency
      // component smearing energy into the wheeze band and causing false
      // positives).
      final hann = 0.5 - 0.5 * cos(2 * pi * i / (windowSizeSamples - 1));
      return raw * hann;
    });

    final spectrum = _fft.realFft(samples);
    final magnitudesSquared = spectrum.discardConjugates().squareMagnitudes();

    var totalEnergy = 0.0;
    var wheezeBandEnergy = 0.0;
    var peakBinEnergy = 0.0;
    var peakBinIndex = -1;
    for (var bin = 0; bin < magnitudesSquared.length; bin++) {
      final energy = magnitudesSquared[bin];
      totalEnergy += energy;
      final freqHz = _fft.frequency(bin, sampleRateHz);
      if (freqHz >= wheezeBandMinHz && freqHz <= wheezeBandMaxHz) {
        wheezeBandEnergy += energy;
        if (energy > peakBinEnergy) {
          peakBinEnergy = energy;
          peakBinIndex = bin;
        }
      }
    }

    final safeTotalEnergy = max(totalEnergy, _minTotalEnergy);
    final ratio = (wheezeBandEnergy / safeTotalEnergy).clamp(0.0, 1.0);

    double? dominantFrequencyHz;
    if (peakBinIndex >= 0 &&
        wheezeBandEnergy > 0 &&
        peakBinEnergy / wheezeBandEnergy >= _dominancePeakFraction) {
      dominantFrequencyHz = _fft.frequency(peakBinIndex, sampleRateHz);
    }

    return WheezeAcousticSample(
      millisecondsSinceStart: millisecondsSinceStart,
      wheezeBandEnergyRatio: ratio,
      dominantFrequencyHz: dominantFrequencyHz,
      totalEnergy: totalEnergy,
    );
  }

  /// Full post-hoc analysis over every window collected during one test
  /// attempt/recording — same "analyze after the fact" shape as
  /// BreathAcousticEngine.analyze / CoughAcousticEngine.analyze.
  WheezeAnalysis analyze(List<WheezeAcousticSample> samples) {
    if (samples.isEmpty) {
      return WheezeAnalysis.none;
    }

    var longestStreakWindows = 0;
    var longestStreakRatioSum = 0.0;
    var longestStreakDurationMs = 0;
    double? longestStreakDominantFrequency;

    var streakWindows = 0;
    var streakRatioSum = 0.0;
    var streakStartMs = 0;
    double? streakDominantFrequency;

    void closeStreak(int endMs) {
      if (streakWindows > longestStreakWindows) {
        longestStreakWindows = streakWindows;
        longestStreakRatioSum = streakRatioSum;
        longestStreakDurationMs = endMs - streakStartMs;
        longestStreakDominantFrequency = streakDominantFrequency;
      }
      streakWindows = 0;
      streakRatioSum = 0;
      streakDominantFrequency = null;
    }

    for (final sample in samples) {
      final inBand = sample.wheezeBandEnergyRatio > wheezeRatioThreshold;
      // A null dominantFrequencyHz means this window's in-band energy
      // didn't concentrate around any single peak (see _analyzeWindow's
      // _dominancePeakFraction check) — i.e. broadband noise that happens
      // to clear the ratio threshold, not a tonal wheeze. It must never
      // count as "the same tone" as a running streak, and on its own it
      // can't start one either: wheeze is a tonal sound by definition, so a
      // window with no discernible tone at all is evidence against a
      // wheeze, not for one, however in-band its raw energy ratio is.
      final hasTone = sample.dominantFrequencyHz != null;
      final sameTone =
          hasTone &&
          (streakDominantFrequency == null ||
              (sample.dominantFrequencyHz! - streakDominantFrequency!).abs() <=
                  dominantFrequencyToleranceHz);

      if (inBand && hasTone && sameTone) {
        if (streakWindows == 0) {
          streakStartMs = sample.millisecondsSinceStart;
        }
        streakWindows++;
        streakRatioSum += sample.wheezeBandEnergyRatio;
        streakDominantFrequency ??= sample.dominantFrequencyHz;
      } else {
        closeStreak(sample.millisecondsSinceStart);
        if (inBand && hasTone) {
          // This window didn't match the previous streak's tone, but it's
          // still in-band and tonal on its own — start a fresh streak from
          // it rather than discarding it.
          streakWindows = 1;
          streakRatioSum = sample.wheezeBandEnergyRatio;
          streakStartMs = sample.millisecondsSinceStart;
          streakDominantFrequency = sample.dominantFrequencyHz;
        }
      }
    }
    closeStreak(samples.last.millisecondsSinceStart + windowDurationMs.round());

    if (longestStreakWindows < minConsecutiveWindowsForWheeze) {
      return WheezeAnalysis.none;
    }

    final meanRatio = longestStreakRatioSum / longestStreakWindows;
    final score = _severityScore(
      longestStreakDurationMs: longestStreakDurationMs,
      meanRatio: meanRatio,
    );
    final level = _severityLevel(score);

    return WheezeAnalysis(
      wheezeDetected: true,
      severityLevel: level,
      severityScore: score,
      wheezeBandEnergyRatio: meanRatio,
      dominantFrequencyHz: longestStreakDominantFrequency,
      wheezeDurationMs: longestStreakDurationMs,
    );
  }

  /// Two-stage (numeric score → level bucket) shape, mirroring
  /// CoughAcousticEngine.severityScore/severityLevel. Duration is weighted
  /// less than intensity (0.4 vs 0.6): a short but very pure tone is still
  /// clinically meaningful, while a long but weak in-band ratio is a weaker
  /// signal on its own.
  int _severityScore({
    required int longestStreakDurationMs,
    required double meanRatio,
  }) {
    final durationSeconds = longestStreakDurationMs / 1000.0;
    final durationScore = (durationSeconds / _fullySustainedSeconds).clamp(
      0.0,
      1.0,
    );
    // 0.75 is the upper anchor for "clearly severe" ratio — a wheeze that
    // dominates 75%+ of the window's spectral energy is unambiguous.
    const upperRatioAnchor = 0.75;
    final ratioScore =
        ((meanRatio - wheezeRatioThreshold) /
                (upperRatioAnchor - wheezeRatioThreshold))
            .clamp(0.0, 1.0);
    final combined = durationScore * 0.4 + ratioScore * 0.6;
    return (combined * 100).round();
  }

  String _severityLevel(int score) {
    if (score <= 0) return 'none';
    if (score < 35) return 'mild';
    if (score < 65) return 'moderate';
    return 'severe';
  }
}
