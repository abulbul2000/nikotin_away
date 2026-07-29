import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_texts.dart';
import '../services/device_permission_service.dart';
import '../services/notification_service.dart';
import 'location_intelligence_page.dart';

class PermissionsCenterPage extends StatefulWidget {
  const PermissionsCenterPage({super.key});

  @override
  State<PermissionsCenterPage> createState() => _PermissionsCenterPageState();
}

class _PermissionsCenterPageState extends State<PermissionsCenterPage>
    with WidgetsBindingObserver {
  bool _notificationsGranted = false;
  bool _microphoneGranted = false;
  bool _activityGranted = false;
  bool _phoneGranted = false;
  bool _locationGranted = false;
  bool _isMiuiDevice = false;
  bool _batteryExemptionGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final notifications = await NotificationService.areNotificationsEnabled();
    final microphone = await Permission.microphone.status;
    final activity = await Permission.activityRecognition.status;
    final phone = await Permission.phone.status;
    final location = await Permission.locationWhenInUse.status;
    final isMiui = await DevicePermissionService.isMiuiDevice();
    final batteryExemption = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notifications;
      _microphoneGranted = microphone.isGranted;
      _activityGranted = activity.isGranted;
      _phoneGranted = phone.isGranted;
      _locationGranted = location.isGranted;
      _isMiuiDevice = isMiui;
      _batteryExemptionGranted = batteryExemption.isGranted;
      _loading = false;
    });
  }

  Future<void> _requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refreshStatuses();
  }

  Future<void> _openAutostartSettings() async {
    await DevicePermissionService.openAutostartSettings();
  }

  Future<void> _requestNotifications() async {
    await NotificationService.ensureNotificationPermission();
    await _refreshStatuses();
  }

  Future<void> _requestMicrophone() async {
    await Permission.microphone.request();
    await _refreshStatuses();
  }

  Future<void> _requestActivity() async {
    await Permission.activityRecognition.request();
    await _refreshStatuses();
  }

  Future<void> _requestPhone() async {
    await Permission.phone.request();
    await _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('permissionsCenterTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.t('permissionsCenterIntro'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                _BackgroundReliabilityCard(
                  granted: _batteryExemptionGranted,
                  onRequestExemption: _requestBatteryExemption,
                  onOpenAutostart: _openAutostartSettings,
                ),
                _PermissionCard(
                  icon: Icons.notifications_outlined,
                  title: context.t('permissionNotificationsTitle'),
                  description: context.t('permissionNotificationsDescription'),
                  purpose: context.t('permissionNotificationsPurpose'),
                  granted: _notificationsGranted,
                  onRequest: _requestNotifications,
                ),
                _PermissionCard(
                  icon: Icons.mic_none_outlined,
                  title: context.t('permissionMicrophoneTitle'),
                  description: context.t('permissionMicrophoneDescription'),
                  purpose: context.t('permissionMicrophonePurpose'),
                  granted: _microphoneGranted,
                  onRequest: _requestMicrophone,
                ),
                _PermissionCard(
                  icon: Icons.directions_walk,
                  title: context.t('permissionActivityTitle'),
                  description: context.t('permissionActivityDescription'),
                  purpose: context.t('permissionActivityPurpose'),
                  granted: _activityGranted,
                  onRequest: _requestActivity,
                ),
                _PermissionCard(
                  icon: Icons.phone_outlined,
                  title: context.t('permissionPhoneTitle'),
                  description: context.t('permissionPhoneDescription'),
                  purpose: context.t('permissionPhonePurpose'),
                  granted: _phoneGranted,
                  onRequest: _requestPhone,
                ),
                _PermissionCard(
                  icon: Icons.place_outlined,
                  title: context.t('permissionLocationTitle'),
                  description: context.t('permissionLocationDescription'),
                  purpose: context.t('permissionLocationPurpose'),
                  granted: _locationGranted,
                  onRequest: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LocationIntelligencePage(),
                      ),
                    );
                  },
                ),
                _PermissionCard(
                  icon: Icons.alarm,
                  title: context.t('permissionExactAlarmTitle'),
                  description: context.t('permissionExactAlarmDescription'),
                  purpose: context.t('permissionExactAlarmPurpose'),
                  granted: null,
                  onRequest: () =>
                      NotificationService.openExactAlarmSettingsOptional(),
                ),
                if (_isMiuiDevice)
                  _PermissionCard(
                    icon: Icons.security_outlined,
                    title: context.t('permissionMiuiTitle'),
                    description: context.t('permissionMiuiDescription'),
                    purpose: context.t('permissionMiuiPurpose'),
                    granted: null,
                    onRequest: () =>
                        DevicePermissionService.openPermissionEditor(),
                  ),
              ],
            ),
    );
  }
}

class _BackgroundReliabilityCard extends StatelessWidget {
  final bool granted;
  final VoidCallback onRequestExemption;
  final VoidCallback onOpenAutostart;

  const _BackgroundReliabilityCard({
    required this.granted,
    required this.onRequestExemption,
    required this.onOpenAutostart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_charging_full, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t('permissionBackgroundTitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: granted
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    granted
                        ? context.t('permissionStatusGranted')
                        : context.t('permissionStatusDenied'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: granted ? Colors.greenAccent : Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.t('permissionBackgroundDescription'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('permissionBackgroundPurpose'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onOpenAutostart,
                    child: Text(
                      context.t('permissionBackgroundOpenSettingsAction'),
                    ),
                  ),
                  if (!granted)
                    OutlinedButton(
                      onPressed: onRequestExemption,
                      child: Text(context.t('permissionActionRequest')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String purpose;
  final bool? granted;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.purpose,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (granted != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: granted!
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      granted!
                          ? context.t('permissionStatusGranted')
                          : context.t('permissionStatusDenied'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: granted! ? Colors.greenAccent : Colors.white60,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 6),
            Text(
              purpose,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (granted != true) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton(
                  onPressed: onRequest,
                  child: Text(
                    granted == false
                        ? context.t('permissionActionRequest')
                        : context.t('permissionActionOpenSettings'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
