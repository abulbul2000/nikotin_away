import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/home_seed_resolver.dart';
import '../main.dart';
import '../services/ambient_audio_service.dart';
import '../services/language_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/google_auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'home_page.dart';
import 'language_selection_page.dart';
import 'login_page.dart';
import 'subscription_gate_page.dart';
import 'trial_info_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _routeFromSplash();
  }

  Future<void> _routeFromSplash() async {
    // Dil seçimi yapılmış mı kontrol et
    final hasSavedLanguage = await LanguageService.hasSavedLanguageSelection();
    if (!mounted) return;

    // Dil seçimi yapılmışsa, normal akışı izle
    if (hasSavedLanguage) {
      final selectedCode = await LanguageService.loadSelectedLanguageCode();
      await AppTexts.ensureLanguageLoaded(selectedCode);
      await NotificationService.refreshLocalizedResources();
      if (!mounted) return;

      NoSmokeApp.setLocale(
        context,
        LanguageService.supportedLanguages[selectedCode] ?? const Locale('en'),
      );

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      _goNext();
      return;
    }

    // Dil seçimi yapılmamışsa, cihaz dilini kontrol et
    final deviceLanguageCode = LanguageService.getDeviceLanguageCode();

    if (deviceLanguageCode != null) {
      // Cihaz dili destekleniyor → otomatik uygula
      await AppTexts.ensureLanguageLoaded(deviceLanguageCode);
      if (!mounted) return;

      NoSmokeApp.setLocale(
        context,
        LanguageService.supportedLanguages[deviceLanguageCode] ??
            const Locale('en'),
      );

      await NotificationService.refreshLocalizedResources();

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      _goNext();
      return;
    }

    // Cihaz dili desteklenmiyor → dil seçme sayfası açılır
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
      );
    }
  }

  Future<void> _goNext() async {
    if (!mounted) return;

    final storage = StorageService();
    var records = await storage.loadSurveyHistory();
    var hasInitialSetup = await storage.hasCompletedInitialSurvey(
      records: records,
    );

    // Google credentials persist across reinstall/login. If this is a fresh
    // local install but the account is already present, restore the full
    // account snapshot before showing onboarding; do not ask the user again.
    if (!hasInitialSetup && GoogleAuthService.isGoogleUser) {
      final restored = await FirestoreSyncService.restoreLocalDatabaseBackup(
        storage,
      );
      if (restored) {
        records = await storage.loadSurveyHistory();
        hasInitialSetup = await storage.hasCompletedInitialSurvey(
          records: records,
        );
      }
      await LoginPage.markLoginAsked();
    }

    if (!mounted) return;

    // İlk kez kurulum yapılmamışsa önce LoginPage göster
    // (Google Sign-In veya skip seçeneği)
    if (!hasInitialSetup) {
      // Eğer henüz login sorulmadıysa LoginPage'e yönlendir
      final loginAsked = await LoginPage.hasLoginBeenAsked();
      if (!loginAsked && !mounted) return;
      if (!loginAsked) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return;
      }
      // Login zaten sorulmuş → normal anket akışı
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
      return;
    }

    // Setup already done. Before letting a returning user into HomePage,
    // check whether the trial has run out and no subscription covers them
    // — this is the primary gate checkpoint (the other is the app-resume
    // lifecycle hook in main.dart, for users who stay on HomePage across
    // the trial boundary).
    final decision = await SubscriptionService().resolveAccess(
      hasCompletedInitialSurvey: true,
    );
    if (!mounted) return;
    if (decision == AccessDecision.showGate ||
        decision == AccessDecision.needsConnectionCheck) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionGatePage(
            needsConnectionOnly:
                decision == AccessDecision.needsConnectionCheck,
          ),
        ),
      );
      return;
    }

    // HomePage's own daily-breath-cadence check
    // (_ensureDailyBreathCadence/_presentDailyBreathMandatoryIfNeeded)
    // already asks "would you like to do it now?" and only makes it
    // mandatory when today's breath test genuinely hasn't been done yet —
    // routing through BreathTestPage unconditionally here duplicated (and
    // fought with) that system, forcing a fresh test on every single app
    // open regardless of whether one had already been done today.
    final seed = HomeSeedResolver.fromRecords(records);

    await AmbientAudioService().startMonitoring();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          name: seed.name,
          riskScore: seed.riskScore,
          riskLevel: seed.riskLevel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                NoSmokeLogo(size: 220, showLabel: true, showTagline: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
