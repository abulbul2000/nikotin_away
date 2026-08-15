import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_texts.dart';
import '../services/firestore_sync_service.dart';
import '../services/google_auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'trial_info_page.dart';

/// First-launch account page.
///
/// Shown once per installation. Offers Google Sign-In so survey + progress
/// data syncs to Firestore (restorable after reinstall). Skipping goes
/// straight to the onboarding survey as an anonymous local-only user.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();

  static const _loginAskedKey = 'login_asked_once';

  static Future<void> markLoginAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginAskedKey, true);
  }

  static Future<bool> hasLoginBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginAskedKey) ?? false;
  }
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;
  bool _restoring = false;
  String _status = '';

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _restoreSurveyContext(
    Map<String, Map<String, dynamic>> restoredContext,
  ) async {
    final storage = StorageService();
    for (final entry in restoredContext.entries) {
      final data = entry.value;
      await storage.saveSurveyDetail(
        recordId: entry.key,
        triggers: _stringList(data['triggers']),
        healthConditions: _stringList(data['healthConditions']),
        firstCigaretteRange: data['firstCigaretteRange']?.toString(),
        smokeFreeRange: data['smokeFreeRange']?.toString(),
        profession: data['profession']?.toString(),
        sleepTime: data['sleepTime']?.toString(),
        wakeTime: data['wakeTime']?.toString(),
        stressLevel: data['stressLevel']?.toString(),
        quitReason: data['quitReason']?.toString(),
        workStart: data['workStart']?.toString(),
        workEnd: data['workEnd']?.toString(),
        workplaceSmokingRule: data['workplaceSmokingRule']?.toString(),
        workingDays: _stringList(data['workingDays']),
        age: _intValue(data['age']),
        smokingYears: _intValue(data['smokingYears']),
        cigarettesPerPack: _intValue(data['cigarettesPerPack']),
      );
      final sleepTime = data['sleepTime']?.toString();
      final wakeTime = data['wakeTime']?.toString();
      if (sleepTime != null && sleepTime.isNotEmpty) {
        await storage.saveSleepTime(sleepTime);
      }
      if (wakeTime != null && wakeTime.isNotEmpty) {
        await storage.saveSetting('wake_time', wakeTime);
      }
      final gender = data['gender']?.toString();
      if (gender != null && gender.isNotEmpty) {
        await storage.saveSetting('gender', gender);
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '';
    });

    final ok = await GoogleAuthService.signInWithGoogle();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Google ile giriş yapılamadı. Tekrar deneyin veya geçin.';
      });
      return;
    }

    // Mark as asked so we don't show again
    await LoginPage.markLoginAsked();

    // Try to restore from cloud
    if (!mounted) return;
    setState(() => _restoring = true);

    final restoredResult =
        await FirestoreSyncService.restoreFromCloud();
    final restoredRecords = restoredResult.$1;
    // restoredContext ($2) — survey details context. Stored for future use.
    // The survey detail save API requires per-record calls which we'll
    // enhance later if needed. For now just restoring survey records.

    if (!mounted) return;

    if (restoredRecords.isNotEmpty) {
      // Restore locally
      final storage = StorageService();
      await storage.saveSurveyHistory(restoredRecords);
      await _restoreSurveyContext(restoredContext);
      await storage.saveInitialRegistrationCompleted(true);

      if (!mounted) return;
      setState(() => _restoring = false);

      final msg = context.t('loginRestoreSuccess').replaceAll(
        '{count}',
        '${restoredRecords.length}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );

      // Go to survey flow which will route to HomePage if setup exists
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
    } else {
      // No cloud data — new user, go to survey
      if (!mounted) return;
      setState(() => _restoring = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
    }
  }

  void _onSkip() async {
    // Mark as "asked once" so we don't show again
    await LoginPage.markLoginAsked();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TrialInfoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const NoSmokeLogo(size: 140, showLabel: true),
                const SizedBox(height: 32),
                Text(
                  context.t('loginTitle'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('loginSubtitle'),
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Google Sign-In button
                ElevatedButton(
                  onPressed: _busy ? null : _onGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        context.t('loginGoogleButton'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Skip button
                OutlinedButton(
                  onPressed: _busy ? null : _onSkip,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.t('loginSkipButton'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  context.t('loginSkipSubtitle'),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),

                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_restoring) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    context.t('loginRestoring'),
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
