import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/device_permission_service.dart';
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
  final IconData icon;
  final Future<bool> Function() isGranted;
  final Future<void> Function() request;

  const _PermissionItem({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.isGranted,
    required this.request,
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

  bool get _allGranted =>
      _items.every((item) => _granted[item.titleKey] == true);

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
                for (final item in _items) ...[
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
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
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
}
