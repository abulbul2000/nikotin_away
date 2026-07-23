import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../main.dart';
import '../services/device_compatibility_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../models/wearable_health_snapshot.dart';
import '../services/health_connect_service.dart';
import '../services/sleep_intelligence_service.dart';
import '../services/storage_service.dart';
import '../services/wearable_intelligence_service.dart';
import '../widgets/background_reliability_prompt.dart';
import 'coach_mode_page.dart';
import 'language_selection_page.dart';
import 'location_intelligence_page.dart';
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
  final WearableIntelligenceService _wearableIntelligenceService =
      WearableIntelligenceService();
  final HealthConnectService _healthConnectService = HealthConnectService();
  final DeviceCompatibilityService _deviceCompatibilityService =
      DeviceCompatibilityService();
  bool _sleepIntelligenceEnabled = false;
  bool _wearableIntelligenceEnabled = false;
  WearableHealthSnapshot _wearableSnapshot = WearableHealthSnapshot.empty;
  bool _wearableSnapshotLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSleepIntelligenceState();
    _loadWearableIntelligenceState();
  }

  Future<void> _loadSleepIntelligenceState() async {
    final enabled = await _sleepIntelligenceService.isEnabled();
    if (!mounted) return;
    setState(() {
      _sleepIntelligenceEnabled = enabled;
    });
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

  Future<void> _openFakeCallerNameSettings() async {
    final current = await _storageService.loadFakeCallerName();
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('fakeCallerNameSettingTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('fakeCallerNameSettingDescription')),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('no')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    await _storageService.saveFakeCallerName(newName);
  }

  void _openPermissionsCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PermissionsCenterPage()),
    );
  }

  void _openCoachMode() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoachModePage()),
    );
  }

  void _openLocationIntelligence() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LocationIntelligencePage()),
    );
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
    await _storageService.clearAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('settingsResetDataDone'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settingsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  leading: const Icon(Icons.person_outline),
                  title: Text(context.t('settingsCallerNameRow')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openFakeCallerNameSettings,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(context.t('settingsCoachModeRow')),
                  subtitle: Text(context.t('settingsCoachModeRowSubtitle')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openCoachMode,
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
                      const Icon(
                        Icons.watch_outlined,
                        color: Colors.white70,
                      ),
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
                          '${_wearableSnapshot.lastSleepSessionDuration!.inHours}s '
                          '${_wearableSnapshot.lastSleepSessionDuration!.inMinutes % 60}d',
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(context.t('settingsResetDataRow')),
              subtitle: Text(context.t('settingsResetDataSubtitle')),
              onTap: _confirmResetData,
            ),
          ),
        ],
      ),
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
