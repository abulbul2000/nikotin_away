import 'package:flutter_tts/flutter_tts.dart';

/// Picks the best available system TTS voice for [locale], preferring a
/// voice whose name hints at [preferredGender] ('male'/'female' — engines
/// almost always encode this in English inside the voice id/name even for
/// non-English locales). Not every engine or locale exposes a gender
/// distinction at all (many locales ship only a single voice), in which
/// case this silently no-ops and that one voice is used as-is.
///
/// [preferLocalVoice]: on-device voices start speaking near-instantly but
/// often sound more robotic; network/cloud voices sound more natural but
/// add a network round-trip before playback starts. Pass true where audio
/// timing matters (the breath test's live acoustic calibration needs the
/// spoken cue and the on-screen step change to land together, and a
/// delayed utterance would land in the wrong mic-listening window); pass
/// false everywhere else so the more natural-sounding voice wins.
Future<void> configureBestVoice(
  FlutterTts tts, {
  required String locale,
  required bool preferLocalVoice,
  String? preferredGender,
}) async {
  try {
    final voices = await tts.getVoices;
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

    var pool = matches;
    if (preferredGender == 'male' || preferredGender == 'female') {
      // 'male' is a substring of 'female', so a naive .contains('male')
      // would also match female-coded voice names — female must be
      // checked (and excluded) first regardless of which gender is wanted.
      bool isFemale(Map v) => '${v['name']}'.toLowerCase().contains('female');
      bool isMale(Map v) =>
          '${v['name']}'.toLowerCase().contains('male') && !isFemale(v);
      final genderMatches = matches
          .where((v) => preferredGender == 'female' ? isFemale(v) : isMale(v))
          .toList();
      if (genderMatches.isNotEmpty) {
        pool = genderMatches;
      }
    }

    final localVoices = pool
        .where((v) => !'${v['name']}'.toLowerCase().contains('network'))
        .toList();
    final networkVoices = pool
        .where((v) => '${v['name']}'.toLowerCase().contains('network'))
        .toList();

    final chosen = preferLocalVoice
        ? (localVoices.isNotEmpty ? localVoices.first : pool.first)
        : (networkVoices.isNotEmpty ? networkVoices.first : pool.first);

    await tts.setVoice({
      'name': '${chosen['name']}',
      'locale': '${chosen['locale']}',
    });
  } catch (_) {
    // Fall back to whatever setLanguage() already selected.
  }
}

/// Maps the app's stored gender answer ('Erkek'/'Kadın', from the initial
/// survey) to the English hint most TTS engines encode in their voice
/// names. Returns null for anything else (unset, "Diğer"/other, etc.) so
/// callers fall back to the engine's default voice instead of guessing.
String? ttsGenderHintFor(String? storedGender) {
  switch (storedGender) {
    case 'Erkek':
      return 'male';
    case 'Kadın':
      return 'female';
    default:
      return null;
  }
}
