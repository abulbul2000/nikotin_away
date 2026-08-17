import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/tts_locale.dart';

void main() {
  const supported = <String>[
    'tr', 'en', 'de', 'ar', 'fr', 'es', 'pt', 'it', 'pl', 'ru',
    'ja', 'zh', 'ko', 'hi', 'bn', 'pa', 'te', 'mr', 'ta', 'gu',
    'kn', 'ml', 'th', 'vi', 'id', 'ms', 'fil', 'uk', 'ro', 'el',
    'hu', 'cs', 'sv', 'da', 'no', 'fi', 'nl', 'be', 'sr', 'hr',
  ];

  test('all 40 supported languages have an explicit TTS locale', () {
    for (final code in supported) {
      expect(
        ttsLocaleForLanguageCode(code),
        isNotNull,
        reason: '$code must have an explicit TTS locale',
      );
    }
  });

  test('TTS does not silently fall back for an unknown language', () {
    expect(ttsLocaleForLanguageCode('xx'), isNull);
  });
}
