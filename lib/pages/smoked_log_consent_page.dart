import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/device_permission_service.dart';
import '../services/smoked_log_button_service.dart';

/// Introduces the quick-log button and turns it on if the user agrees.
///
/// Explains first, then asks for the permission the button needs. The order
/// matters: "allow this app to draw over other apps" means nothing on its
/// own, and asking for it cold is how a permission gets refused. It used to
/// be the other way round — the offer checked for the permission and gave up
/// silently when it was missing, so the one feature that tells the app when
/// the user actually smokes was never even mentioned to most people.
///
/// Returns true when the button ended up enabled.
/// [service] is injectable so the ordering above can be tested. Widget tests
/// run in a fake-async zone where a real SQLite read never resolves, and the
/// first thing this does is read a setting — so without the seam the whole
/// flow is unreachable from a test.
Future<bool> offerSmokedLogButton(
  BuildContext context, {
  SmokedLogButtonService? service,
}) async {
  final buttonService = service ?? SmokedLogButtonService();
  if (await buttonService.hasEverConsented()) {
    return false;
  }
  if (!context.mounted) return false;

  final accepted = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const SmokedLogConsentPage()));
  if (accepted != true || !context.mounted) {
    return false;
  }

  // Read before the permission trip: the system screen takes the user out of
  // the app, and this BuildContext must not be touched afterwards.
  final notificationTitle = context.t('smokedLogButtonNotificationTitle');
  final notificationBody = context.t('smokedLogButtonNotificationBody');
  final actionLabel = context.t('smokedLogButtonAction');
  final menuLabels = <String, String?>{
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
    'channelDescription': context.t('channelDescriptionSmokedLogQuickAction'),
  };

  if (!await DevicePermissionService.hasOverlayPermission()) {
    // Granting happens outside the app, so there is nothing to await —
    // enable() reports honestly if the button still can't be drawn, and the
    // switch in settings stays available either way.
    await DevicePermissionService.requestOverlayPermission();
  }

  return buttonService.enable(
    notificationTitle: notificationTitle,
    notificationBody: notificationBody,
    actionLabel: actionLabel,
    menuLabels: menuLabels,
  );
}

/// Shown once, before the quick-log button is switched on for the first time.
///
/// A plain settings toggle would have been enough for a button that only
/// recorded a timestamp. This one also matches the moment against the user's
/// known places, and location — even reduced to "which of your usual spots" —
/// is not something to start collecting behind a switch someone flicked
/// without reading. The screen states what is kept, what deliberately isn't,
/// and that it never leaves the phone.
///
/// Returns true when the user accepted.
class SmokedLogConsentPage extends StatelessWidget {
  const SmokedLogConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('smokedLogButtonTitle'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                children: [
                  Text(
                    context.t('smokedLogConsentHeading'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('smokedLogButtonDescription'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t('smokedLogButtonPurpose'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    icon: Icons.fact_check_outlined,
                    title: context.t('smokedLogConsentDataTitle'),
                    body: context.t('smokedLogConsentDataBody'),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    icon: Icons.phonelink_lock_outlined,
                    title: context.t('smokedLogConsentStorageTitle'),
                    body: context.t('smokedLogConsentStorageBody'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('smoked_log_consent_accept'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(context.t('smokedLogConsentAccept')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const ValueKey('smoked_log_consent_decline'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.t('smokedLogConsentDecline')),
                    ),
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

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
