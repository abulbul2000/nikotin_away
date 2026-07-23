import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the breath test's phase cues (hold / exhale) aloud via the
/// device's on-device TTS engine, using the app's existing TR/EN
/// instruction strings — no bundled audio assets needed. Best-effort: any
/// TTS failure (engine missing, language unsupported) is swallowed, since
/// the on-screen text cues already fully cover the same guidance.
///
/// The phone's own speaker output leaks back into its microphone (this is
/// normal — most phones aren't built for echo cancellation between the two
/// during simultaneous playback+recording), so whatever this speaks would
/// otherwise get picked up as "noise" by the breath test's live acoustic
/// detection and corrupt its calibration. [onSpeakingStateChanged] reports
/// exactly when audio is actually playing so the caller can ignore mic
/// samples for that window.
class BreathVoiceGuideService {
  final FlutterTts _tts;
  bool _ready = false;
  void Function(bool speaking)? onSpeakingStateChanged;

  // Callers fire speak()/stop() with `unawaited(...)` right after a
  // setState() that changes the on-screen step text, so two calls can
  // easily overlap in-flight (e.g. a hold-retry timer firing right as the
  // user taps through a step) — without serializing them, a `stop()` from
  // the second call could land *between* the first call's own stop() and
  // speak(), cancelling the wrong utterance and leaving stale audio
  // playing under the new step's text. Chaining every call onto this
  // queue guarantees they always run fully in order.
  Future<void> _queue = Future<void>.value();

  BreathVoiceGuideService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setStartHandler(() => onSpeakingStateChanged?.call(true));
    _tts.setCompletionHandler(() => onSpeakingStateChanged?.call(false));
    _tts.setCancelHandler(() => onSpeakingStateChanged?.call(false));
    _tts.setErrorHandler((_) => onSpeakingStateChanged?.call(false));
  }

  Future<void> setLanguage(String languageCode) async {
    final locale = languageCode == 'tr' ? 'tr-TR' : 'en-US';
    try {
      await _preferHighQualityEngine();
      await _tts.setLanguage(locale);
      await _preferHighQualityVoice(locale);
      // Natural conversational pace rather than a deliberately slow
      // "instructional" cadence — a slower rate reads as more halting/
      // robotic, not clearer, on most modern TTS voices.
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Best-effort: Android ships with whatever TTS engine the manufacturer
  /// bundled, which on some phones sounds noticeably more robotic than
  /// Google's own engine. If Google's engine is installed on the device,
  /// prefer it — most Android phones have it (it backs the system
  /// "Assistant" voice), but it isn't guaranteed, so this silently no-ops
  /// if it's missing rather than failing the whole setup.
  Future<void> _preferHighQualityEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List &&
          engines.any((e) => e.toString() == 'com.google.android.tts')) {
        await _tts.setEngine('com.google.android.tts');
      }
    } catch (_) {
      // Fall back to whatever the device's default engine already is.
    }
  }

  /// Best-effort voice pick, deliberately favoring *local* voices over
  /// "network"/cloud ones. Network voices often sound a bit more natural,
  /// but they synthesize by round-tripping to a server first — on real
  /// devices that shows up as exactly the 1-2s "text appears, then it
  /// speaks a beat later" lag this was built to avoid. Since the on-screen
  /// text and the voice cue are meant to land together, a slightly more
  /// robotic but near-instant local voice is the right trade here.
  Future<void> _preferHighQualityVoice(String locale) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) {
        return;
      }
      final matches = voices
          .whereType<Map>()
          .where(
            (v) =>
                '${v['locale']}'.toLowerCase().replaceAll('_', '-') ==
                locale.toLowerCase(),
          )
          .toList();
      if (matches.isEmpty) {
        return;
      }
      final localVoice = matches.firstWhere(
        (v) => !'${v['name']}'.toLowerCase().contains('network'),
        orElse: () => matches.first,
      );
      await _tts.setVoice({
        'name': '${localVoice['name']}',
        'locale': '${localVoice['locale']}',
      });
    } catch (_) {
      // Fall back to whatever setLanguage() already selected.
    }
  }

  Future<void> speak(String text) {
    return _enqueue(() async {
      if (!_ready) {
        return;
      }
      try {
        await _tts.stop();
        await _tts.speak(text);
      } catch (_) {
        // Best-effort — on-screen text already carries the same guidance.
      }
    });
  }

  Future<void> stop() {
    return _enqueue(() async {
      try {
        await _tts.stop();
      } catch (_) {
        // Ignore — nothing to clean up if it was never speaking.
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // Swallow errors here so one failed call doesn't wedge the queue for
    // every call after it — each action already handles its own errors,
    // this is only a backstop.
    _queue = next.catchError((_) {});
    return next;
  }

  void dispose() {
    unawaited(stop());
  }
}
