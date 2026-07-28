import 'package:flutter/material.dart';

import '../core/app_texts.dart';

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

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

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
