import 'package:share_plus/share_plus.dart';

import '../core/app_texts.dart';

/// Shares the public Nicotine Away installation link without exposing user data.
class AppShareService {
  AppShareService._();

  static const androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.nikotinaway.app';

  static Future<void> shareApp({required String languageCode}) async {
    final appName = AppTexts.textForCode(languageCode, 'appName');
    final title = AppTexts.textForCode(languageCode, 'shareAppTitle');
    final message = AppTexts.textForCode(languageCode, 'shareAppMessage')
        .replaceAll('{appName}', appName)
        .replaceAll('{url}', androidStoreUrl);

    await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: message,
      ),
    );
  }
}
