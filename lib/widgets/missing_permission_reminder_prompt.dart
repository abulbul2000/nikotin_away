import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_texts.dart';
import '../engines/missing_permission_reminder_engine.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// One entry in the rotation this prompt cycles through. [status] reads the
/// permission's current grant state; [request] triggers the OS prompt (or,
/// for notifications, the app's own enable path) when the user accepts.
class _ReminderablePermission {
  const _ReminderablePermission({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.purposeKey,
    required this.status,
    required this.request,
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final String purposeKey;
  final Future<bool> Function() status;
  final Future<void> Function() request;
}

List<_ReminderablePermission> _candidates() => [
  _ReminderablePermission(
    id: 'notifications',
    titleKey: 'permissionNotificationsTitle',
    descriptionKey: 'permissionNotificationsDescription',
    purposeKey: 'permissionNotificationsPurpose',
    status: () async => NotificationService.areNotificationsEnabled(),
    request: () async => NotificationService.ensureNotificationPermission(),
  ),
  _ReminderablePermission(
    id: 'microphone',
    titleKey: 'permissionMicrophoneTitle',
    descriptionKey: 'permissionMicrophoneDescription',
    purposeKey: 'permissionMicrophonePurpose',
    status: () async => Permission.microphone.status.then((s) => s.isGranted),
    request: () async {
      await Permission.microphone.request();
    },
  ),
  _ReminderablePermission(
    id: 'activityRecognition',
    titleKey: 'permissionActivityTitle',
    descriptionKey: 'permissionActivityDescription',
    purposeKey: 'permissionActivityPurpose',
    status: () async =>
        Permission.activityRecognition.status.then((s) => s.isGranted),
    request: () async {
      await Permission.activityRecognition.request();
    },
  ),
  _ReminderablePermission(
    id: 'phone',
    titleKey: 'permissionPhoneTitle',
    descriptionKey: 'permissionPhoneDescription',
    purposeKey: 'permissionPhonePurpose',
    status: () async => Permission.phone.status.then((s) => s.isGranted),
    request: () async {
      await Permission.phone.request();
    },
  ),
  _ReminderablePermission(
    id: 'batteryOptimization',
    titleKey: 'permissionBackgroundTitle',
    descriptionKey: 'permissionBackgroundDescription',
    purposeKey: 'permissionBackgroundPurpose',
    status: () async =>
        Permission.ignoreBatteryOptimizations.status.then((s) => s.isGranted),
    request: () async {
      await Permission.ignoreBatteryOptimizations.request();
    },
  ),
];

String _snoozeKey(String permissionId) =>
    'permission_reminder_snooze_until_$permissionId';
String _neverAskAgainKey(String permissionId) =>
    'permission_reminder_never_ask_again_$permissionId';

/// Cycles through the permissions above, showing at most one Accept/
/// Postpone/Decline dialog per call — never a pile of stacked prompts.
/// Silent (shows nothing) once every permission is either granted or
/// dismissed for good, which is the steady state for most returning users.
/// Callers are expected to gate how often this runs (e.g. once per app
/// launch, at most once a day) the same way
/// [maybePromptBackgroundReliability] is gated from `home_page.dart`.
Future<void> maybePromptMissingPermission({
  required BuildContext context,
  required StorageService storageService,
}) async {
  final candidates = _candidates();
  final grantedIds = <String>{};
  for (final candidate in candidates) {
    if (await candidate.status()) {
      grantedIds.add(candidate.id);
    }
  }

  final neverAskAgainIds = <String>{};
  final snoozedUntil = <String, DateTime>{};
  for (final candidate in candidates) {
    if (grantedIds.contains(candidate.id)) continue;
    final neverAskRaw = await storageService.loadSetting(
      _neverAskAgainKey(candidate.id),
    );
    if (neverAskRaw == 'true') {
      neverAskAgainIds.add(candidate.id);
      continue;
    }
    final snoozeRaw = await storageService.loadSetting(
      _snoozeKey(candidate.id),
    );
    final parsed = snoozeRaw == null ? null : DateTime.tryParse(snoozeRaw);
    if (parsed != null) {
      snoozedUntil[candidate.id] = parsed;
    }
  }

  const engine = MissingPermissionReminderEngine();
  final dueId = engine.nextPermissionDue(
    candidates: candidates.map((c) => c.id).toList(),
    grantedPermissionIds: grantedIds,
    neverAskAgainPermissionIds: neverAskAgainIds,
    snoozedUntilByPermissionId: snoozedUntil,
    now: DateTime.now(),
  );
  if (dueId == null || !context.mounted) return;

  final due = candidates.firstWhere((c) => c.id == dueId);
  await _showReminderDialog(
    context: context,
    storageService: storageService,
    permission: due,
  );
}

Future<void> _showReminderDialog({
  required BuildContext context,
  required StorageService storageService,
  required _ReminderablePermission permission,
}) async {
  var dontShowAgain = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(dialogContext.t(permission.titleKey)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dialogContext.t(permission.descriptionKey)),
            const SizedBox(height: 8),
            Text(
              dialogContext.t(permission.purposeKey),
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => dontShowAgain = !dontShowAgain),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (value) =>
                        setState(() => dontShowAgain = value ?? false),
                  ),
                  Flexible(
                    child: Text(
                      dialogContext.t('permissionReminderDontShowAgain'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _applyDecision(
                storageService: storageService,
                permissionId: permission.id,
                dontShowAgain: dontShowAgain,
                decision: _ReminderDecision.decline,
              );
            },
            child: Text(dialogContext.t('permissionReminderActionDecline')),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _applyDecision(
                storageService: storageService,
                permissionId: permission.id,
                dontShowAgain: dontShowAgain,
                decision: _ReminderDecision.postpone,
              );
            },
            child: Text(dialogContext.t('permissionReminderActionPostpone')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await permission.request();
              // Accepted: no snooze/never-ask-again bookkeeping needed —
              // once granted, nextPermissionDue skips it via grantedIds on
              // the very next call.
            },
            child: Text(dialogContext.t('permissionReminderActionAccept')),
          ),
        ],
      ),
    ),
  );
}

enum _ReminderDecision { postpone, decline }

Future<void> _applyDecision({
  required StorageService storageService,
  required String permissionId,
  required bool dontShowAgain,
  required _ReminderDecision decision,
}) async {
  // "Don't show again" wins regardless of which button it was checked
  // under — postpone or decline both mean "not now"; the checkbox is the
  // one signal that means "and stop asking permanently."
  if (dontShowAgain) {
    await storageService.saveSetting(
      _neverAskAgainKey(permissionId),
      'true',
    );
    return;
  }
  final snoozeUntil = DateTime.now().add(
    MissingPermissionReminderEngine.snoozeDuration,
  );
  await storageService.saveSetting(
    _snoozeKey(permissionId),
    snoozeUntil.toIso8601String(),
  );
}
