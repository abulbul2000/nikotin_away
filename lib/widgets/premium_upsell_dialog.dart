import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../pages/subscription_gate_page.dart';
import '../services/feature_access.dart';

/// Shown in place of a full-screen [SubscriptionGatePage] wall when the user
/// taps into a [PremiumFeature] without an active trial/subscription — a
/// small in-place prompt rather than losing the screen they were on.
/// "Yükselt" routes to [SubscriptionGatePage] (still reachable, still the
/// only place a purchase actually happens); dismissing just closes the
/// dialog and leaves the user exactly where they were.
Future<void> showPremiumUpsellDialog(
  BuildContext context, {
  required String messageKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.t('premiumUpsellTitle')),
      content: Text(dialogContext.t(messageKey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('premiumUpsellDismiss')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionGatePage()),
            );
          },
          child: Text(dialogContext.t('premiumUpsellUpgrade')),
        ),
      ],
    ),
  );
}

/// Runs [FeatureAccess.canAccess] for [feature] and either calls [onGranted]
/// (the caller's normal navigation) or shows the upsell dialog — the one
/// place a menu entry point needs to call to be feature-gated.
Future<void> guardPremiumFeature(
  BuildContext context, {
  required PremiumFeature feature,
  required String upsellMessageKey,
  required VoidCallback onGranted,
  FeatureAccess? featureAccess,
}) async {
  final access = featureAccess ?? FeatureAccess();
  final allowed = await access.canAccess(feature);
  if (!context.mounted) return;
  if (allowed) {
    onGranted();
    return;
  }
  await showPremiumUpsellDialog(context, messageKey: upsellMessageKey);
}
