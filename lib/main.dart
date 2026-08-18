import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'core/app_texts.dart';
import 'core/app_theme.dart';
import 'pages/splash_page.dart';
import 'pages/subscription_gate_page.dart';
import 'services/google_auth_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/sleep_intelligence_service.dart';
import 'services/subscription_service.dart';

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

  try {
    await GoogleAuthService.initialize();
  } catch (error, stackTrace) {
    debugPrint('[main] Google Sign-In init failed (non-blocking): $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // App Check + anonymous auth back the aiChat/verifySubscription Cloud
  // Functions (see functions/index.js) so a caller can't forge trial/
  // subscription proof — but neither may ever block app startup: a user
  // with no network yet on first launch still needs to reach the home
  // screen, and these silently retry the next time a callable is invoked.
  try {
    // In debug builds a server-generated debug token can be passed via
    // `flutter run --dart-define=APP_CHECK_DEBUG_SECRET=<secret>` so the
    // Firebase Console "Manage debug tokens" entry lets this build pass
    // App Check (needed by the enforceAppCheck Cloud Functions).
    const String debugSecret = String.fromEnvironment('APP_CHECK_DEBUG_SECRET');
    if (kDebugMode) {
      // Development Functions do not enforce App Check. Do not generate an
      // unregistered debug token by default; that token is rejected as
      // invalid by callable request verification. A registered token can
      // still be supplied explicitly when needed.
      if (debugSecret.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidDebugProvider(debugToken: debugSecret),
        );
      }
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[main] App Check activation failed (non-blocking): $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (error, stackTrace) {
    debugPrint('[main] Anonymous sign-in failed (non-blocking): $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  await NotificationService.initialize(navigatorKey: navigatorKey);
  final locale = await LanguageService.loadSelectedLocale();
  await AppTexts.ensureLanguageLoaded(locale.languageCode);
  runApp(NoSmokeApp(initialLocale: locale));
  // Re-arm Sleep Intelligence from the user's configured window or, once
  // enough trusted data exists, from the behavior engine's learned window.
  unawaited(SleepIntelligenceService().refreshScheduleIfEnabled());

  // Cold start: if the app was opened by tapping a notification while
  // fully terminated (not background), route to the correct page now.
  // This handles the case where onDidReceiveNotificationResponse never
  // fires because the isolate wasn't running at tap time.
  NotificationService.handleColdStartIfLaunchedFromNotification();
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
  DateTime? _lastAccessCheckAt;
  static const _accessCheckDebounce = Duration(minutes: 5);
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    WidgetsBinding.instance.addObserver(this);
    // App-lifetime purchase listener. SubscriptionGatePage has its own
    // listener too (for its own UI state — pending spinner, closing on
    // success), but that one only exists while the gate page is mounted.
    // Without this one, a purchase that settles to PURCHASED while the app
    // is backgrounded (or the user simply isn't on the gate page — e.g. a
    // deferred/pending payment method that confirms hours later) never
    // reaches handlePurchase, so completePurchase is never called and Play
    // auto-refunds the purchase after 3 days despite the user having paid.
    // purchaseStream is a broadcast stream (see
    // in_app_purchase_android_platform.dart), so having two listeners is
    // safe — both receive every event, and handlePurchase itself is safe
    // to run twice for the same purchase (it just re-verifies and
    // completePurchase is a no-op for an already-completed transaction).
    _purchaseSubscription = SubscriptionService().purchaseStream.listen((
      purchases,
    ) async {
      for (final purchase in purchases) {
        await SubscriptionService().handlePurchase(purchase);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSubscription?.cancel();
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
      // The watchdog queues a violation + closes the matching task natively
      // while the app is dead (see NoResponseWatchdogService.kt); this is
      // also drained on cold start (NotificationService.initialize), but a
      // user who only ever looks at notifications from the lock screen and
      // never force-quits/reopens the app could otherwise sit on an
      // unsynced violation indefinitely — resuming from the background is
      // the other moment that's reliably reachable.
      unawaited(NotificationService.syncWatchdogViolationsFromNative());
      unawaited(_recheckAccessOnResume());
    }
  }

  /// Catches the case a user stayed on HomePage across the trial-expiry
  /// boundary (SplashPage's own gate check only runs on cold start).
  /// Debounced so a user backgrounding/foregrounding repeatedly doesn't
  /// hit storage on every flip — the cached subscription_state is only a
  /// few minutes stale at worst, which is fine for this check.
  Future<void> _recheckAccessOnResume() async {
    final now = DateTime.now();
    final last = _lastAccessCheckAt;
    if (last != null && now.difference(last) < _accessCheckDebounce) {
      return;
    }
    _lastAccessCheckAt = now;

    final storage = StorageService();
    final hasSurvey = await storage.hasCompletedInitialSurvey();
    if (!hasSurvey) {
      // Onboarding itself owns navigation until the survey is done.
      return;
    }
    final decision = await SubscriptionService().resolveAccess(
      hasCompletedInitialSurvey: true,
    );
    if (decision != AccessDecision.showGate &&
        decision != AccessDecision.needsConnectionCheck) {
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SubscriptionGatePage(
          needsConnectionOnly: decision == AccessDecision.needsConnectionCheck,
        ),
      ),
      (route) => false,
    );
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
