import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_texts.dart';
import 'core/app_theme.dart';
import 'pages/splash_page.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize(navigatorKey: navigatorKey);
  final locale = await LanguageService.loadSelectedLocale();
  await AppTexts.ensureLanguageLoaded(locale.languageCode);
  runApp(NoSmokeApp(initialLocale: locale));
}

class NoSmokeApp extends StatefulWidget {
  final Locale initialLocale;

  const NoSmokeApp({super.key, required this.initialLocale});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_NoSmokeAppState>();
    state?.setLocale(locale);
  }

  @override
  State<NoSmokeApp> createState() => _NoSmokeAppState();
}

class _NoSmokeAppState extends State<NoSmokeApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'No Smoke',
      theme: AppTheme.darkTheme,
      locale: _locale,
      supportedLocales: LanguageService.supportedLanguages.values.toList(
        growable: false,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashPage(),
    );
  }
}
