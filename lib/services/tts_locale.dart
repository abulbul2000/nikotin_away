/// Maps every language code the app's UI supports (see LanguageService /
/// generated_language_data.dart) to a BCP-47 locale tag the platform TTS
/// engine understands. Shared by every feature that speaks app text aloud
/// (breath test voice cues, the mandatory-task voice announcement) so a
/// language gets added here once and every TTS caller picks it up.
const Map<String, String> ttsLocaleByLanguageCode = {
  'tr': 'tr-TR',
  'en': 'en-US',
  'de': 'de-DE',
  'ar': 'ar-SA',
  'fr': 'fr-FR',
  'es': 'es-ES',
  'pt': 'pt-BR',
  'it': 'it-IT',
  'pl': 'pl-PL',
  'ru': 'ru-RU',
  'ja': 'ja-JP',
  'zh': 'zh-CN',
  'ko': 'ko-KR',
  'hi': 'hi-IN',
  'bn': 'bn-IN',
  'pa': 'pa-IN',
  'te': 'te-IN',
  'mr': 'mr-IN',
  'ta': 'ta-IN',
  'gu': 'gu-IN',
  'kn': 'kn-IN',
  'ml': 'ml-IN',
  'th': 'th-TH',
  'vi': 'vi-VN',
  'id': 'id-ID',
  'ms': 'ms-MY',
};

String ttsLocaleForLanguageCode(String languageCode) {
  return ttsLocaleByLanguageCode[languageCode] ?? 'en-US';
}
