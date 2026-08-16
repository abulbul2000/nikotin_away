import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_texts.dart';
import '../services/cloud_backup_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/google_auth_service.dart';
import '../services/storage_service.dart';
import '../models/medication.dart';
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

  dynamic _decodeJson(dynamic value) {
    if (value is! String || value.isEmpty) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  List<Map<String, String>> _breakWindows(dynamic value) {
    final decoded = _decodeJson(value);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((row) {
      return row.map((key, value) => MapEntry(key.toString(), value.toString()));
    }).toList();
  }

  List<Map<String, dynamic>> _medicationRows(dynamic value) {
    final decoded = _decodeJson(value);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((row) {
      return row.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
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
        breakWindows: _breakWindows(data['breakWindowsJson']),
        weekendSmokingPattern: data['weekendSmokingPattern']?.toString(),
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
      final interventionIntensity = data['interventionIntensity']?.toString();
      if (interventionIntensity != null && interventionIntensity.isNotEmpty) {
        await storage.saveInterventionIntensity(interventionIntensity);
      }
      for (final key in [
        'schoolType',
        'packOption',
        'hasSmokingBreaks',
        'hasSecondBreak',
        'consecutiveSmokingHabit',
        'consecutiveSmokingCount',
        'usesMedication',
      ]) {
        final value = data[key];
        if (value != null) {
          await storage.saveSetting(key, value.toString());
        }
      }
      final medications = _medicationRows(data['medicationsJson']);
      for (var i = 0; i < medications.length; i++) {
        final row = medications[i];
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        await storage.saveMedication(
          Medication(
            id: 'restored_${entry.key}_$i',
            name: name,
            times: _stringList(row['times']),
            createdAt: DateTime.now(),
          ),
        );
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
    final storage = StorageService();
    final fullBackupRestored =
        await FirestoreSyncService.restoreLocalDatabaseBackup(storage);
    if (fullBackupRestored) {
      await storage.saveInitialRegistrationCompleted(true);
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('loginRestoreSuccess'))),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
      return;
    }
    final restoredResult =
        await FirestoreSyncService.restoreFromCloud();
    final restoredRecords = restoredResult.$1;
    final restoredContext = restoredResult.$2;

    if (!mounted) return;

    if (restoredRecords.isNotEmpty) {
      // Restore locally
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

  Future<void> _onEmailSignIn() async {
    if (_busy) return;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var createAccount = false;
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dialogContext.t('loginEmailButton')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: dialogContext.t('loginEmailAddress'),
                ),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: dialogContext.t('loginEmailPassword'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: createAccount,
                onChanged: (value) =>
                    setDialogState(() => createAccount = value ?? false),
                title: Text(dialogContext.t('loginEmailCreate')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'email': emailController.text,
                'password': passwordController.text,
                'create': createAccount,
              }),
              child: Text(dialogContext.t('loginEmailButton')),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    passwordController.dispose();
    if (!mounted || request == null) return;

    setState(() {
      _busy = true;
      _restoring = true;
      _status = '';
    });
    final ok = await GoogleAuthService.signInWithEmail(
      email: request['email']?.toString() ?? '',
      password: request['password']?.toString() ?? '',
      createAccount: request['create'] == true,
    );
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _restoring = false;
        _status = context.t('loginEmailInvalid');
      });
      return;
    }

    await LoginPage.markLoginAsked();
    final storage = StorageService();
    await FirestoreSyncService.restoreLocalDatabaseBackup(storage);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _restoring = false;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TrialInfoPage()),
    );
  }

  Future<void> _onRestoreBackup() async {
    if (_busy) return;
    final controller = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t('cloudRestoreRow')),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: dialogContext.t('cloudRestorePassphrase'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(dialogContext.t('cloudRestoreRow')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || passphrase == null || passphrase.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _restoring = true;
      _status = '';
    });
    try {
      final restored = await CloudBackupService().restore(
        passphrase: passphrase.trim(),
      );
      if (!mounted) return;
      if (!restored) {
        setState(() {
          _busy = false;
          _restoring = false;
          _status = context.t('cloudRestoreNotFound');
        });
        return;
      }
      await LoginPage.markLoginAsked();
      setState(() {
        _busy = false;
        _restoring = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _restoring = false;
        _status = context.t('cloudRestoreFailed');
      });
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

                // Email/Firebase account option.
                OutlinedButton.icon(
                  onPressed: _busy ? null : _onEmailSignIn,
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    context.t('loginEmailButton'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Restore an encrypted passphrase backup without Google.
                OutlinedButton.icon(
                  onPressed: _busy ? null : _onRestoreBackup,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    context.t('cloudRestoreRow'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // First-time user button.
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
