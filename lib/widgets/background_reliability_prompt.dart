import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_texts.dart';
import '../services/device_compatibility_service.dart';
import '../services/device_permission_service.dart';

/// Phase 12: shown right after the user turns on a background-reliant
/// feature (Sleep/Location Intelligence) on a device
/// [DeviceCompatibilityService] flags as likely to kill that background
/// work — the contextual, adaptive counterpart to the passive
/// always-there card in the Permissions Center. No-ops silently (shows
/// nothing) when the device isn't a known-aggressive manufacturer or the
/// exemption is already granted, so most users never see this at all.
/// Reuses the exact same disclosure text as the Permissions Center card
/// for consistency rather than inventing new copy.
Future<void> maybePromptBackgroundReliability({
  required BuildContext context,
  required DeviceCompatibilityService deviceCompatibilityService,
}) async {
  final atRisk = await deviceCompatibilityService
      .isBackgroundReliabilityAtRisk();
  if (!atRisk || !context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.t('permissionBackgroundTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dialogContext.t('permissionBackgroundDescription')),
          const SizedBox(height: 8),
          Text(
            dialogContext.t('permissionBackgroundPurpose'),
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('no')),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await Permission.ignoreBatteryOptimizations.request();
          },
          child: Text(dialogContext.t('permissionActionRequest')),
        ),
        OutlinedButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await DevicePermissionService.openAutostartSettings();
          },
          child: Text(dialogContext.t('permissionBackgroundOpenSettingsAction')),
        ),
      ],
    ),
  );
}
