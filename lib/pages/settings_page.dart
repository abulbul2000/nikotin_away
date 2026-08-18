import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_page.dart';

import '../core/app_texts.dart';
import '../main.dart';
import '../services/cloud_backup_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/google_auth_service.dart';
import '../services/device_compatibility_service.dart';
import '../services/feature_access.dart';
import '../services/language_service.dart';
import '../widgets/share_app_sheet.dart';
import '../services/notification_service.dart';
import '../models/wearable_health_snapshot.dart';
import '../services/health_connect_service.dart';
import '../services/sleep_intelligence_service.dart';
import '../services/smoked_log_button_service.dart';
import '../services/storage_service.dart';
import '../services/wearable_intelligence_service.dart';
import '../widgets/background_reliability_prompt.dart';
import '../widgets/notification_kinds_card.dart';
import '../widgets/premium_upsell_dialog.dart';
import 'coach_mode_page.dart';
import 'language_selection_page.dart';
import 'location_intelligence_page.dart';
import 'medications_page.dart';
import 'permission_setup_page.dart';
import 'smoked_log_consent_page.dart';
import 'permissions_center_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storageService = StorageService();
  final SleepIntelligenceService _sleepIntelligenceService =
      SleepIntelligenceService();
  final SmokedLogButtonService _smokedLogButtonService =
      SmokedLogButtonService();
  final WearableIntelligenceService _wearableIntelligenceService =
      WearableIntelligenceService();
  final HealthConnectService _healthConnectService = HealthConnectService();
  final DeviceCompatibilityService _deviceCompatibilityService =
      DeviceCompatibilityService();
  bool _sleepIntelligenceEnabled = false;
  bool _durationBarrierEnabled = true;
  bool _smokedLogButtonEnabled = false;
  bool _wearableIntelligenceEnabled = false;
  WearableHealthSnapshot _wearableSnapshot = WearableHealthSnapshot.empty;
  bool _wearableSnapshotLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSleepIntelligenceState();
    _loadDurationBarrierState();
    _loadSmokedLogButtonState();
    _loadWearableIntelligenceState();
  }

  Future<void> _loadSleepIntelligenceState() async {
    final enabled = await _sleepIntelligenceService.isEnabled();
    if (!mounted) return;
    setState(() {
      _sleepIntelligenceEnabled = enabled;
    });
  }

  /// Mirrors coach_mode_page.dart's own on/off switch — that page holds the
  /// only detail (frequency), but consent has to be visible from the top-
  /// level Settings list too, not buried a screen deeper where someone who
  /// wants the barrier off entirely might never think to look.
  Future<void> _loadDurationBarrierState() async {
    final raw = await _storageService.loadSetting('duration_barrier_enabled');
    if (!mounted) return;
    setState(() {
      _durationBarrierEnabled = raw != '0';
    });
  }

  Future<void> _toggleDurationBarrier(bool value) async {
    await _storageService.saveSetting(
      'duration_barrier_enabled',
      value ? '1' : '0',
    );
    if (!mounted) return;
    setState(() => _durationBarrierEnabled = value);
  }

  Future<void> _loadSmokedLogButtonState() async {
    final enabled = await _smokedLogButtonService.isEnabled();
    if (!mounted) return;
    setState(() {
      _smokedLogButtonEnabled = enabled;
    });
  }

  Future<void> _toggleSmokedLogButton(bool value) async {
    if (!value) {
      await _smokedLogButtonService.disable();
      if (!mounted) return;
      setState(() => _smokedLogButtonEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('smokedLogButtonDisabled'))),
      );
      return;
    }

    // Shown before the first switch-on only. The button records where the
    // user was, reduced to one of their own known places — not something to
    // start collecting off a toggle nobody read.
    if (!await _smokedLogButtonService.hasEverConsented()) {
      if (!mounted) return;
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SmokedLogConsentPage()),
      );
      if (!mounted || accepted != true) {
        return;
      }
    }

    if (!mounted) return;
    final started = await _smokedLogButtonService.enable(
      notificationTitle: context.t('smokedLogButtonNotificationTitle'),
      notificationBody: context.t('smokedLogButtonNotificationBody'),
      actionLabel: context.t('smokedLogButtonAction'),
      menuLabels: {
        'menuTitle': context.t('smokedLogMenuTitle'),
        'menuSosLabel': context.t('smokedLogMenuSos'),
        'menuOpenLabel': context.t('smokedLogMenuOpen'),
        'menuCancelLabel': context.t('smokedLogMenuCancel'),
        'triggerTitle': context.t('triggerTitle'),
        'triggerStress': context.t('triggerStress'),
        'triggerCoffee': context.t('triggerCoffee'),
        'triggerMeal': context.t('triggerMeal'),
        'triggerAlcohol': context.t('triggerAlcohol'),
        'triggerPhone': context.t('triggerPhone'),
        'triggerDriving': context.t('triggerDriving'),
        'triggerWork': context.t('triggerWork'),
        'triggerSocial': context.t('triggerSocial'),
        'triggerBoredom': context.t('triggerBoredom'),
        'triggerHabit': context.t('triggerHabit'),
        'triggerUnknown': context.t('triggerUnknown'),
        'channelName': context.t('channelNameSmokedLogQuickAction'),
        'channelDescription': context.t(
          'channelDescriptionSmokedLogQuickAction',
        ),
      },
    );
    if (!mounted) return;

    // enable() reports failure rather than storing a preference for a button
    // that can't be drawn — without the overlay permission the switch would
    // otherwise sit on while nothing appeared on screen.
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('smokedLogButtonNeedsOverlay'))),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PermissionSetupPage()),
      );
      if (!mounted) return;
      await _loadSmokedLogButtonState();
      return;
    }

    setState(() => _smokedLogButtonEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('smokedLogButtonEnabled'))),
    );
  }

  Future<void> _toggleSleepIntelligence(bool value) async {
    if (value) {
      await _sleepIntelligenceService.enable();
    } else {
      await _sleepIntelligenceService.disable();
    }
    if (!mounted) return;
    setState(() {
      _sleepIntelligenceEnabled = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            value
                ? 'sleepIntelligenceEnabledConfirmation'
                : 'sleepIntelligenceDisabledConfirmation',
          ),
        ),
      ),
    );
    if (value) {
      await maybePromptBackgroundReliability(
        context: context,
        deviceCompatibilityService: _deviceCompatibilityService,
      );
    }
  }

  Future<void> _loadWearableIntelligenceState() async {
    final enabled = await _wearableIntelligenceService.isEnabled();
    if (!mounted) return;
    setState(() {
      _wearableIntelligenceEnabled = enabled;
    });
    if (enabled) {
      unawaited(_refreshWearableSnapshot());
    }
  }

  Future<void> _refreshWearableSnapshot() async {
    setState(() {
      _wearableSnapshotLoading = true;
    });
    final snapshot = await _healthConnectService.fetchRecentSnapshot();
    if (!mounted) return;
    setState(() {
      _wearableSnapshot = snapshot;
      _wearableSnapshotLoading = false;
    });
  }

  Future<void> _toggleWearableIntelligence(bool value) async {
    if (!value) {
      await _wearableIntelligenceService.disable();
      if (!mounted) return;
      setState(() {
        _wearableIntelligenceEnabled = false;
        _wearableSnapshot = WearableHealthSnapshot.empty;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('wearableIntelligenceDisabledConfirmation')),
        ),
      );
      return;
    }

    final available = await _healthConnectService.isAvailable();
    if (!available) {
      if (!mounted) return;
      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(context.t('wearableIntelligenceUnavailable')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('no')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('wearableIntelligenceInstallAction')),
            ),
          ],
        ),
      );
      if (shouldInstall == true) {
        await _healthConnectService.promptInstall();
      }
      return;
    }

    final enabled = await _wearableIntelligenceService.enable();
    if (!mounted) return;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('wearableIntelligencePermissionDenied')),
        ),
      );
      return;
    }
    setState(() {
      _wearableIntelligenceEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('wearableIntelligenceEnabledConfirmation')),
      ),
    );
    unawaited(_refreshWearableSnapshot());
  }

  Future<void> _shareApp() async {
    await showShareAppSheet(context);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  Future<void> _openLanguageSettings() async {
    final initialCode = await LanguageService.loadSelectedLanguageCode();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return LanguageSelectionModal(
          selectedCode: initialCode,
          onLanguageSelected: (code) async {
            await LanguageService.saveSelectedLanguageCode(code);
            await AppTexts.ensureLanguageLoaded(code);
            await NotificationService.refreshLocalizedResources();
            if (!mounted) return;
            NoSmokeApp.setLocale(
              context,
              LanguageService.supportedLanguages[code] ?? const Locale('en'),
            );
            if (modalContext.mounted) Navigator.of(modalContext).pop();
          },
        );
      },
    );
  }

  void _openPermissionsCenter() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PermissionsCenterPage()));
  }

  void _openCoachMode() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CoachModePage()));
  }

  Future<void> _openLocationIntelligence() async {
    await guardPremiumFeature(
      context,
      feature: PremiumFeature.locationIntelligence,
      upsellMessageKey: 'premiumUpsellLocationIntelligence',
      onGranted: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LocationIntelligencePage()),
        );
      },
    );
  }

  void _openMedications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MedicationsPage()));
  }

  Future<void> _deleteAccountAndCloudData() async {
    if (!GoogleAuthService.isCloudUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('accountDeleteRequiresLogin'))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('accountDeleteTitle')),
        content: Text(context.t('accountDeleteMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('accountDeleteAction')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // A background syncLocalDatabaseBackup fired earlier (e.g. on app
      // resume) may still be uploading. Wait for it to finish first so it
      // cannot write cloud data back after deleteAllCloudData() below.
      await FirestoreSyncService.waitForPendingSync();
      await FirestoreSyncService.deleteAllCloudData();
      await deleteAllBackupsForCurrentUser();
      await _storageService.clearAllData();
      await GoogleAuthService.deleteCurrentAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('accountDeleteDone'))));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'requires-recent-login'
          ? context.t('accountDeleteRecentLogin')
          : context.t('accountDeleteFailed');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('accountDeleteFailed'))));
    }
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('settingsResetDataConfirmTitle')),
        content: Text(context.t('settingsResetDataConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('settingsResetDataConfirmAction')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // See _confirmDeleteAccount: a background syncLocalDatabaseBackup may
    // still be reading from storage. Let it finish before wiping so it
    // does not race clearAllData() and re-upload a half-cleared snapshot.
    await FirestoreSyncService.waitForPendingSync();
    await _storageService.clearAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('settingsResetDataDone'))));
  }

  /// The passphrase is the only key to a user's backup — never stored,
  /// never shown again, and there is deliberately no "forgot passphrase"
  /// recovery (see CloudBackupService docs: that's what makes it
  /// zero-knowledge). This dialog exists once and is reused for both
  /// backup and restore so the warning is seen every time either runs.
  Future<String?> _promptPassphrase({required bool isRestore}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isRestore
              ? context.t('cloudRestoreRow')
              : context.t('cloudBackupRow'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRestore
                  ? context.t('cloudRestorePassphraseHint')
                  : context.t('cloudBackupPassphraseHint'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t(
                  isRestore
                      ? 'cloudRestorePassphraseLabel'
                      : 'cloudBackupPassphraseLabel',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              isRestore
                  ? context.t('cloudRestoreRow')
                  : context.t('cloudBackupRow'),
            ),
          ),
        ],
      ),
    );
    // The showDialog future can resolve before the pop transition (and thus
    // the TextField holding this controller) has actually finished
    // unmounting, so disposing synchronously here can hit the framework's
    // "_dependents.isEmpty" assertion. Deferring to the next frame lets the
    // route finish tearing down first.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final trimmed = result?.trim();
    return (trimmed == null || trimmed.length < 6) ? null : trimmed;
  }

  Future<void> _confirmCloudBackup() async {
    if (!GoogleAuthService.isCloudUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('accountDeleteRequiresLogin'))),
      );
      return;
    }
    final passphrase = await _promptPassphrase(isRestore: false);
    if (passphrase == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('cloudBackupPassphraseTooShort'))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupInProgress'))));
    try {
      await CloudBackupService(
        storageService: _storageService,
      ).backup(passphrase: passphrase);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupSuccess'))));
    } catch (error, stackTrace) {
      debugPrint('[SettingsPage] Cloud backup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupFailed'))));
    }
  }

  Future<void> _confirmCloudRestore() async {
    if (!GoogleAuthService.isCloudUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('accountDeleteRequiresLogin'))),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('cloudRestoreRow')),
        content: Text(context.t('cloudRestoreConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('cloudRestoreRow')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final passphrase = await _promptPassphrase(isRestore: true);
    if (passphrase == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('cloudBackupPassphraseTooShort'))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupInProgress'))));
    try {
      final found = await CloudBackupService(
        storageService: _storageService,
      ).restore(passphrase: passphrase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            found
                ? context.t('cloudRestoreSuccess')
                : context.t('cloudRestoreNotFound'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[SettingsPage] Cloud restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('cloudRestoreFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(context.t('notifKindsSectionTitle')),
        const NotificationKindsCard(),
        const SizedBox(height: 20),

        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.t('settingsNotificationsRow')),
            subtitle: Text(context.t('settingsNotificationsRowSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openNotifications,
          ),
        ),
        _SectionLabel(context.t('settingsSectionGeneral')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.t('settingsLanguageRow')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openLanguageSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(context.t('shareAppTitle')),
                subtitle: Text(context.t('shareAppMessage').split('\n').first),
                trailing: const Icon(Icons.chevron_right),
                onTap: _shareApp,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(context.t('durationBarrierEnabledTitle')),
                subtitle: Text(context.t('durationBarrierEnabledDescription')),
                trailing: Switch(
                  value: _durationBarrierEnabled,
                  onChanged: _toggleDurationBarrier,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: Text(context.t('settingsCoachModeRow')),
                subtitle: Text(context.t('settingsCoachModeRowSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openCoachMode,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: Text(context.t('medicationsSettingsRow')),
                subtitle: Text(context.t('medicationsSettingsRowSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openMedications,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('settingsSleepIntelligenceRow')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bedtime_outlined, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('sleepIntelligenceTitle'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: _sleepIntelligenceEnabled,
                      onChanged: _toggleSleepIntelligence,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('sleepIntelligenceDescription'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('sleepIntelligencePurpose'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('sleepIntelligenceSnoringIncluded'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('smokedLogButtonRow')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.smoking_rooms_outlined,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('smokedLogButtonTitle'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      key: const ValueKey('smoked_log_button_switch'),
                      value: _smokedLogButtonEnabled,
                      onChanged: _toggleSmokedLogButton,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('smokedLogButtonDescription'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('smokedLogButtonPurpose'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('settingsWearableIntelligenceRow')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.watch_outlined, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('wearableIntelligenceTitle'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: _wearableIntelligenceEnabled,
                      onChanged: _toggleWearableIntelligence,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('wearableIntelligenceDescription'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('wearableIntelligencePurpose'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_wearableIntelligenceEnabled) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (_wearableSnapshotLoading)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (!_wearableSnapshot.hasAnyData)
                    Text(
                      context.t('wearableIntelligenceNoData'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    )
                  else ...[
                    if (_wearableSnapshot.latestHeartRateBpm != null)
                      Text(
                        '${context.t('wearableIntelligenceLatestHeartRate')}: '
                        '${_wearableSnapshot.latestHeartRateBpm!.round()} bpm',
                      ),
                    if (_wearableSnapshot.lastSleepSessionDuration != null)
                      Text(
                        '${context.t('wearableIntelligenceLastSleep')}: '
                        '${AppTexts.formatAdaptiveDurationPhrase(Localizations.localeOf(context).languageCode, _wearableSnapshot.lastSleepSessionDuration!.inMinutes)}',
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('settingsSectionPrivacy')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.t('settingsPermissionsRow')),
            subtitle: Text(context.t('settingsPermissionsRowSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openPermissionsCenter,
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('settingsLocationIntelligenceRow')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(context.t('settingsLocationIntelligenceRow')),
            subtitle: Text(
              context.t('settingsLocationIntelligenceRowSubtitle'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openLocationIntelligence,
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('settingsSectionData')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.t('cloudBackupPhoneChangeWarning'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(context.t('cloudBackupRow')),
                subtitle: Text(context.t('cloudBackupRowSubtitle')),
                onTap: _confirmCloudBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(context.t('cloudRestoreRow')),
                subtitle: Text(context.t('cloudRestoreRowSubtitle')),
                onTap: _confirmCloudRestore,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.redAccent,
                ),
                title: Text(context.t('accountDeleteRow')),
                subtitle: Text(context.t('accountDeleteSubtitle')),
                onTap: _deleteAccountAndCloudData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text(context.t('settingsResetDataRow')),
            subtitle: Text(context.t('settingsResetDataSubtitle')),
            onTap: _confirmResetData,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
