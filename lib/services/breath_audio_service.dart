import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../engines/breath_acoustic_engine.dart';
import '../models/breath_acoustic_sample.dart';

/// Thin wrapper around the `record` package for the breath test's live
/// exhale detection. Every audio chunk is converted to a single RMS energy
/// float the instant it arrives and the chunk itself is discarded
/// immediately after — raw audio bytes never leave this method on their
/// own, are never buffered here, and are never written to disk. Only the
/// resulting scalar samples (see BreathAcousticEngine) are kept in memory
/// for the duration of one test attempt.
///
/// The optional [onRawChunk] callback on [startListening] is the one
/// exception: when a caller supplies it, the same transient chunk is also
/// handed to that callback synchronously, before this method returns. It
/// exists for WheezeDetectionEngine, which needs frequency information
/// `computeRmsEnergy`'s single time-domain scalar can't provide — but the
/// same discipline applies on the caller's side: WheezeDetectionEngine
/// reduces each chunk to a few spectral-summary floats
/// (WheezeAcousticSample) and never retains the chunk itself either.
class BreathAudioService {
  final AudioRecorder _recorder;
  final BreathAcousticEngine _engine;
  StreamSubscription<Uint8List>? _subscription;
  DateTime? _startedAt;

  BreathAudioService({AudioRecorder? recorder, BreathAcousticEngine? engine})
    : _recorder = recorder ?? AudioRecorder(),
      _engine = engine ?? BreathAcousticEngine();

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts listening and invokes [onSample] for each derived energy
  /// reading, timestamped relative to when listening began. Returns false
  /// (caller falls back to the manual-tap timing flow) if the microphone
  /// couldn't be started at all — never throws.
  ///
  /// [onRawChunk], when provided, receives the same chunk [onSample] was
  /// derived from — see the class doc comment for what callers are expected
  /// to do (and not do) with it.
  Future<bool> startListening(
    void Function(BreathAcousticSample) onSample, {
    void Function(Uint8List rawChunk, int millisecondsSinceStart)? onRawChunk,
  }) async {
    if (!await hasPermission()) {
      return false;
    }
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          // The default Android audio source runs automatic gain control
          // (and often noise suppression) in the OS itself, which actively
          // works against energy-envelope exhale detection: AGC normalizes
          // quiet-vs-loud swings in real time, flattening exactly the
          // baseline-to-exhale energy jump BreathAcousticEngine looks for.
          // This shows up as "the mic doesn't reliably detect the exhale" —
          // worse on manufacturers (e.g. MIUI) that run more aggressive
          // audio processing by default. voiceRecognition is Android's own
          // documented "no AGC / no echo cancellation" source (broader
          // hardware support than the newer `unprocessed` source, which
          // isn't guaranteed to exist on every device).
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
          ),
        ),
      );
      _startedAt = DateTime.now();
      _subscription = stream.listen((chunk) {
        final startedAt = _startedAt;
        if (startedAt == null) {
          return;
        }
        final energy = _engine.computeRmsEnergy(chunk);
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        onRawChunk?.call(chunk, elapsedMs);
        onSample(
          BreathAcousticSample(
            millisecondsSinceStart: elapsedMs,
            rmsEnergy: energy,
          ),
        );
      }, onError: (_) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Best-effort — recorder may already be stopped/disposed.
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _recorder.dispose();
  }
}
