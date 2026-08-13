# UI Screen Catalog

- generatedAt: 2026-08-13T07:26:43.684245
- activeLanguageCode: tr
- screenFolder: ui_catalog/screens
- catalogFile: ui_catalog/catalog/screen_catalog.json

| Screen ID | Screen Name | App Location | Screenshot | Sources | Components | Translation Keys | Style Sources | Theme Sources |
|---|---|---|---|---|---|---|---|---|
| SCR-0001-SPLASH | Splash | App start | ui_catalog/screens/SCR-0001-SPLASH.png | lib/pages/splash_page.dart | Scaffold<br>NoSmokeLogo<br>SafeArea | appName | lib/pages/splash_page.dart | lib/core/app_theme.dart |
| SCR-0002-LANGUAGE | LanguageSelection | Onboarding -> language | ui_catalog/screens/SCR-0002-LANGUAGE.png | lib/pages/language_selection_page.dart | NoSmokeLogo<br>GestureDetector<br>Container | selectLanguage<br>continue<br>otherLanguages | lib/pages/language_selection_page.dart | lib/core/app_theme.dart |
| SCR-0003-LANGUAGE-MODAL | LanguageSelectionModal | LanguageSelection -> bottom sheet | ui_catalog/screens/SCR-0003-LANGUAGE-MODAL.png | lib/pages/language_selection_page.dart | DraggableScrollableSheet<br>TextField<br>ListTile | searchLanguages<br>otherLanguages<br>backToMain | lib/pages/language_selection_page.dart | lib/core/app_theme.dart |
| SCR-0004-TRIAL-INFO | TrialInfo | Onboarding -> trial info | ui_catalog/screens/SCR-0004-TRIAL-INFO.png | lib/pages/trial_info_page.dart | NoSmokeLogo<br>Card<br>FilledButton | trialInfoTitle<br>trialInfoMessage<br>continue | lib/pages/trial_info_page.dart | lib/core/app_theme.dart |
| SCR-0010-MANDATORY-TASK | MandatoryTask | Home -> mandatory task gate | ui_catalog/screens/SCR-0010-MANDATORY-TASK.png | lib/pages/mandatory_task_page.dart | PopScope<br>Card<br>ElevatedButton | mandatoryTaskTitle<br>mandatoryTaskHint | lib/pages/mandatory_task_page.dart | lib/core/app_theme.dart |
