import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import 'storage_service.dart';

class LanguageService {
  static const String _languageCodeKey = 'selected_language_code';

  // Top 40 dilleri - primary ve other
  static const Map<String, Locale> supportedLanguages = {
    // Primary (featured first)
    'tr': Locale('tr'),
    'en': Locale('en'),
    'de': Locale('de'),
    'ar': Locale('ar'),
    'fr': Locale('fr'),
    'es': Locale('es'),
    // Other languages (top 35)
    'pt': Locale('pt'),
    'it': Locale('it'),
    'pl': Locale('pl'),
    'ru': Locale('ru'),
    'ja': Locale('ja'),
    'zh': Locale('zh'),
    'ko': Locale('ko'),
    'hi': Locale('hi'),
    'bn': Locale('bn'),
    'pa': Locale('pa'),
    'te': Locale('te'),
    'mr': Locale('mr'),
    'ta': Locale('ta'),
    'gu': Locale('gu'),
    'kn': Locale('kn'),
    'ml': Locale('ml'),
    'th': Locale('th'),
    'vi': Locale('vi'),
    'id': Locale('id'),
    'ms': Locale('ms'),
    'fil': Locale('fil'),
    'uk': Locale('uk'),
    'ro': Locale('ro'),
    'el': Locale('el'),
    'hu': Locale('hu'),
    'cs': Locale('cs'),
    'sv': Locale('sv'),
    'da': Locale('da'),
    'no': Locale('no'),
    'fi': Locale('fi'),
    'nl': Locale('nl'),
    'be': Locale('be'),
    'sr': Locale('sr'),
    'hr': Locale('hr'),
    'ku': Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Latn'),
    'ku-arab': Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Arab'),
  };

  // Dil adları (UI'da gösterilecek)
  static const Map<String, String> languageNames = {
    'tr': 'Türkçe',
    'en': 'English',
    'de': 'Deutsch',
    'ar': 'العربية',
    'fr': 'Français',
    'es': 'Español',
    'pt': 'Português',
    'it': 'Italiano',
    'pl': 'Polski',
    'ru': 'Русский',
    'ja': '日本語',
    'zh': '中文',
    'ko': '한국어',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
    'pa': 'ਪੰਜਾਬੀ',
    'te': 'తెలుగు',
    'mr': 'मराठी',
    'ta': 'தமிழ்',
    'gu': 'ગુજરાતી',
    'kn': 'ಕನ್ನಡ',
    'ml': 'മലയാളം',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'id': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
    'fil': 'Filipino',
    'uk': 'Українська',
    'ro': 'Română',
    'el': 'Ελληνικά',
    'hu': 'Magyar',
    'cs': 'Čeština',
    'sv': 'Svenska',
    'da': 'Dansk',
    'no': 'Norsk',
    'fi': 'Suomi',
    'nl': 'Nederlands',
    'be': 'Беларуская',
    'sr': 'Српски',
    'hr': 'Hrvatski',
    'ku': 'Kurmancî',
    'ku-arab': 'سۆرانی',
  };

  // Primary 6 dilleri (ilk seçenekler)
  static const List<String> primaryLanguages = [
    'tr',
    'en',
    'de',
    'ar',
    'fr',
    'es',
  ];

  static Future<String> loadSelectedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_languageCodeKey)?.toLowerCase();

    // A saved value is an explicit user override. If it is absent (or was
    // removed from the supported list in a later release), use the device's
    // preferred supported language before falling back to English.
    if (savedCode != null && supportedLanguages.containsKey(savedCode)) {
      return savedCode;
    }
    return getDeviceLanguageCode() ?? 'en';
  }

  static Future<bool> hasSavedLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_languageCodeKey);
  }

  static Future<Locale> loadSelectedLocale() async {
    final code = await loadSelectedLanguageCode();
    return supportedLanguages[code] ?? const Locale('en');
  }

  static Future<void> saveSelectedLanguageCode(String languageCode) async {
    final code = languageCode.toLowerCase();
    if (!supportedLanguages.containsKey(code)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
    await StorageService().saveLanguageSelectionHistory(code);
  }

  static Future<void> clearSelectedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageCodeKey);
  }

  /// Cihazın dil ayarını al (dil kodu döndür veya null).
  /// Kullanıcının telefonda tanımlı TÜM tercih ettiği dilleri sırayla
  /// kontrol eder (ör. birincil dil desteklenmiyorsa ikincil tercihe
  /// bakar), böylece "telefonunda hangi dil varsa" en iyi eşleşme bulunur.
  static String? getDeviceLanguageCode() {
    for (final locale in PlatformDispatcher.instance.locales) {
      final baseCode = locale.languageCode.toLowerCase();
      final code = baseCode == 'ku' && locale.scriptCode == 'Arab'
          ? 'ku-arab'
          : baseCode;
      if (supportedLanguages.containsKey(code)) {
        return code;
      }
    }

    // Geriye dönük uyumluluk: locales listesi boşsa tekil locale'e bak.
    final fallbackLocale = PlatformDispatcher.instance.locale;
    final fallbackBaseCode = fallbackLocale.languageCode.toLowerCase();
    final fallbackCode = fallbackBaseCode == 'ku' &&
            fallbackLocale.scriptCode == 'Arab'
        ? 'ku-arab'
        : fallbackBaseCode;
    if (supportedLanguages.containsKey(fallbackCode)) {
      return fallbackCode;
    }

    // Desteklenmiyorsa null
    return null;
  }

  /// Belirtilen dil kodunun desteklenip desteklenmediğini kontrol et
  static bool isLanguageSupported(String languageCode) {
    return supportedLanguages.containsKey(languageCode);
  }
}
