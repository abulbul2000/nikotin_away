import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/home_seed_resolver.dart';
import '../main.dart';
import '../services/ambient_audio_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'breath_test_page.dart';
import 'language_selection_page.dart';
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
    final records = await storage.loadSurveyHistory();

    final hasInitialSetup = await storage.hasCompletedInitialSurvey(
      records: records,
    );

    if (!mounted) return;

    // İlk kez kurulum yapılmamışsa TrialInfoPage'e git
    if (!hasInitialSetup) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
      return;
    }

    // Setup yapılmışsa BreathTestPage'e git
    final seed = HomeSeedResolver.fromRecords(records);

    await AmbientAudioService().startMonitoring();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: seed.name,
          packsPerDay: seed.packsPerDay,
          navigateToHomeOnComplete: true,
          askWeeklySurveyOnComplete: true,
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
                NoSmokeLogo(
                  size: 180,
                  showLabel: true,
                  iconColor: Color(0xFFE3425A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
