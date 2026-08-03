import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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

  // Crash reporting is opt-out-able by the user later (settings), but must
  // be wired up before anything else can crash — best-effort: a Firebase
  // init failure (e.g. no network on first launch) must never block the
  // app from starting.
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (error, stackTrace) {
    debugPrint(
      '[main] Firebase/Crashlytics init failed (non-blocking): $error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

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

class _NoSmokeAppState extends State<NoSmokeApp> with WidgetsBindingObserver {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A reminder overlay's "Open" button launches the app and queues a
    // route natively (see ReminderOverlayStore) rather than navigating
    // itself — resuming is the only moment that queued route can be picked
    // up and acted on.
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService.syncOverlayStateFromNative());
    }
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
      title: 'Nikotin Away',
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
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.08,
                    child: Image(
                      // The card-less mark: the launcher version would render
                      // its light background as a faint pale square rather
                      // than the artwork itself.
                      image: AssetImage(
                        'assets/images/no_smoke_logo_transparent.png',
                      ),
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      home: const SplashPage(),
    );
  }
}
