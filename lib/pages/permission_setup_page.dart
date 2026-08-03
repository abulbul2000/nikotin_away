import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../core/app_texts.dart';
import '../services/device_permission_service.dart';
import '../services/health_connect_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';

/// One screen for the permissions the task system needs, each with its own
/// live status.
///
/// This replaces a run of separate dialogs. They were shown back to back and
/// worded almost identically — same two buttons, same shape — so arriving at
/// the second one right after returning from Settings read as the first one
/// having reappeared. Worse, nothing rechecked anything: tapping "open
/// settings" fired the intent and the flow moved on regardless, so the app
/// never learned whether permission had actually been granted and could not
/// acknowledge it either way.
///
/// Being a screen rather than a dialog is what makes the recheck possible:
/// it observes the lifecycle and refreshes every row when the user comes
/// back, so a row they just granted is already ticked when they look at it.
class PermissionSetupPage extends StatefulWidget {
  const PermissionSetupPage({super.key});

  @override
  State<PermissionSetupPage> createState() => _PermissionSetupPageState();
}

class _PermissionItem {
  final String titleKey;
  final String descriptionKey;

  /// Shown alongside the description in the "why" dialog, for the items that
  /// have a separate "Neden:" line. Null when the description already says
  /// everything worth saying.
  final String? purposeKey;
  final IconData icon;
  final Future<bool> Function() isGranted;
  final Future<void> Function() request;

  /// Whether the task system cannot work without this one. Only the
  /// required items count toward "everything is granted" and toward the
  /// continue button's wording — the optional ones (microphone, location,
  /// activity recognition, Health Connect) back features the user may never
  /// switch on at all, so withholding them is not something to nag about.
  final bool required;

  const _PermissionItem({
    required this.titleKey,
    required this.descriptionKey,
    this.purposeKey,
    required this.icon,
    required this.isGranted,
    required this.request,
    this.required = true,
  });
}

class _PermissionSetupPageState extends State<PermissionSetupPage>
    with WidgetsBindingObserver {
  late final List<_PermissionItem> _items;
  final Map<String, bool> _granted = {};
  bool _loading = true;

  /// Only offered on devices that hide the relevant toggles behind their own
  /// editor, so the list doesn't carry a row most users can't act on.
  bool _showsOemRow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _items = [
      _PermissionItem(
        titleKey: 'permissionNotificationsTitle',
        descriptionKey: 'permissionNotificationsDescription',
        icon: Icons.notifications_active_outlined,
        isGranted: NotificationService.areNotificationsEnabled,
        request: () async {
          await NotificationService.ensureNotificationPermission();
        },
      ),
      _PermissionItem(
        titleKey: 'overlayPermissionTitle',
        descriptionKey: 'permissionOverlayDescription',
        icon: Icons.picture_in_picture_alt_outlined,
        isGranted: DevicePermissionService.hasOverlayPermission,
        request: () async {
          await DevicePermissionService.requestOverlayPermission();
        },
      ),
      // Below this point: permissions the *optional* features need. Each one
      // used to be requested only when the user switched that feature on, in
      // a different screen at a different moment — which is a large part of
      // why permissions felt scattered across the app. Granting one here
      // only grants it; it never switches the feature on by itself, so the
      // toggle in Settings still decides whether Sleep Intelligence, Location
      // Intelligence etc. actually run.
      _PermissionItem(
        titleKey: 'permissionMicrophoneTitle',
        descriptionKey: 'permissionMicrophoneDescription',
        purposeKey: 'permissionMicrophonePurpose',
        icon: Icons.mic_none_outlined,
        isGranted: () async => (await ph.Permission.microphone.status).isGranted,
        request: () async {
          await ph.Permission.microphone.request();
        },
        required: false,
      ),
      _PermissionItem(
        titleKey: 'permissionLocationTitle',
        descriptionKey: 'permissionLocationDescription',
        purposeKey: 'permissionLocationPurpose',
        icon: Icons.place_outlined,
        isGranted: () async => (await ph.Permission.locationAlways.status).isGranted,
        request: () async {
          // Foreground first, then background — the order Android requires.
          final foreground = await ph.Permission.locationWhenInUse.request();
          if (foreground.isGranted) {
            await ph.Permission.locationAlways.request();
          }
        },
        required: false,
      ),
      _PermissionItem(
        titleKey: 'permissionActivityTitle',
        descriptionKey: 'permissionActivityDescription',
        purposeKey: 'permissionActivityPurpose',
        icon: Icons.directions_walk_outlined,
        isGranted: () async =>
            (await ph.Permission.activityRecognition.status).isGranted,
        request: () async {
          await ph.Permission.activityRecognition.request();
        },
        required: false,
      ),
      _PermissionItem(
        titleKey: 'permissionHealthTitle',
        descriptionKey: 'permissionHealthDescription',
        icon: Icons.favorite_border,
        isGranted: () => HealthConnectService().hasPermissions(),
        request: () async {
          await HealthConnectService().requestPermissions();
        },
        required: false,
      ),
      _PermissionItem(
        titleKey: 'permissionUsageAccessTitle',
        descriptionKey: 'permissionUsageAccessDescription',
        purposeKey: 'permissionUsageAccessPurpose',
        icon: Icons.apps_outlined,
        isGranted: DevicePermissionService.hasUsageAccessPermission,
        request: () async {
          await DevicePermissionService.requestUsageAccessPermission();
        },
        required: false,
      ),
    ];
    unawaitedRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The whole point of the screen: granting happens in Settings, in another
    // app, so resuming is the only moment the result can be observed.
    if (state == AppLifecycleState.resumed) {
      unawaitedRefresh();
    }
  }

  void unawaitedRefresh() {
    _refresh();
  }

  Future<void> _refresh() async {
    final results = <String, bool>{};
    for (final item in _items) {
      try {
        results[item.titleKey] = await item.isGranted();
      } catch (_) {
        results[item.titleKey] = false;
      }
    }
    final isMiui = await DevicePermissionService.isMiuiDevice();
    if (!mounted) {
      return;
    }
    setState(() {
      _granted
        ..clear()
        ..addAll(results);
      _showsOemRow = isMiui;
      _loading = false;
    });
  }

  Future<void> _handleRequest(_PermissionItem item) async {
    await item.request();
    if (!mounted) {
      return;
    }
    // Covers the case where the request resolves in-app (a runtime dialog)
    // rather than by leaving for Settings — didChangeAppLifecycleState never
    // fires for those.
    await _refresh();
  }

  Future<void> _openOemEditor() async {
    final opened = await DevicePermissionService.openPermissionEditor();
    if (!opened) {
      await PermissionService.openPermissionSettings();
    }
  }

  String _fullDescription(_PermissionItem item) {
    final description = context.t(item.descriptionKey);
    final purposeKey = item.purposeKey;
    if (purposeKey == null) {
      return description;
    }
    return '$description\n\n${context.t(purposeKey)}';
  }

  bool get _allGranted => _items
      .where((item) => item.required)
      .every((item) => _granted[item.titleKey] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('permissionSetupTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.t('permissionSetupIntro'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                for (final item in _items.where((item) => item.required)) ...[
                  _buildRow(
                    icon: item.icon,
                    title: context.t(item.titleKey),
                    description: context.t(item.descriptionKey),
                    granted: _granted[item.titleKey] == true,
                    onRequest: () => _handleRequest(item),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showsOemRow)
                  _buildRow(
                    icon: Icons.tune_outlined,
                    title: context.t('miuiPermissionTitle'),
                    description: context.t('permissionOemDescription'),
                    // The OEM editor exposes no readable state, so this row
                    // can only offer the shortcut — never claim it's done.
                    granted: null,
                    onRequest: _openOemEditor,
                  ),
                const SizedBox(height: 24),
                Text(
                  context.t('permissionSetupOptionalHeading'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('permissionSetupOptionalHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final item in _items.where((item) => !item.required)) ...[
                  _buildRow(
                    icon: item.icon,
                    title: context.t(item.titleKey),
                    description: _fullDescription(item),
                    granted: _granted[item.titleKey] == true,
                    onRequest: () => _handleRequest(item),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  key: const ValueKey('permission_setup_continue'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.t(
                      _allGranted ? 'continue' : 'permissionSetupContinueAnyway',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('permissionSetupOptionalNote'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String title,
    required String description,
    required bool? granted,
    required VoidCallback onRequest,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              granted == true ? Icons.check_circle : icon,
              color: granted == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Why-this-permission, on demand rather than always on
                      // the row: the full explanation is a paragraph, and a
                      // paragraph under every row is what made this screen
                      // feel crowded before it even had anything to grant.
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showWhyDialog(
                          title: title,
                          description: description,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (granted != true) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onRequest,
                      child: Text(context.t('miuiPermissionOpen')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWhyDialog({
    required String title,
    required String description,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('doneShort')),
          ),
        ],
      ),
    );
  }
}
