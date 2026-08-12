import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/subscription_service.dart';
import '../widgets/no_smoke_logo.dart';

/// The full-app lock screen shown once the 14-day trial has ended and no
/// valid subscription is on record — [AccessDecision.showGate] /
/// [AccessDecision.needsConnectionCheck] both route here. There is no way
/// out of this screen other than a successful purchase, a restored
/// purchase, or a fresh connectivity check resolving to [allowed] — see
/// SplashPage/[NoSmokeApp.didChangeAppLifecycleState] for the two places
/// that route here.
///
/// Purchase buttons are wired to real `in_app_purchase` calls in a later
/// phase; this page's job for now is the gate UI and the "recheck access"
/// plumbing so callers already have somewhere real to send a locked-out
/// user.
class SubscriptionGatePage extends StatefulWidget {
  final bool needsConnectionOnly;

  const SubscriptionGatePage({super.key, this.needsConnectionOnly = false});

  @override
  State<SubscriptionGatePage> createState() => _SubscriptionGatePageState();
}

class _SubscriptionGatePageState extends State<SubscriptionGatePage> {
  bool _checking = false;

  Future<void> _retryConnection() async {
    setState(() => _checking = true);
    // Re-resolving access here only re-reads the cached subscription_state
    // row; the real server re-verification lands in the purchase-flow
    // phase. This still lets a user who just regained connectivity move
    // on immediately once that phase writes a fresh lastVerifiedAt.
    final decision = await SubscriptionService().resolveAccess(
      hasCompletedInitialSurvey: true,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    if (decision == AccessDecision.allowed) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NoSmokeLogo(size: 120, showLabel: true),
                    const SizedBox(height: 24),
                    Text(
                      context.t('subscriptionGateTitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t(
                        widget.needsConnectionOnly
                            ? 'subscriptionNeedsConnection'
                            : 'subscriptionGateMessage',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!widget.needsConnectionOnly) ...[
                      _SubscriptionOptionCard(
                        title: context.t('subscriptionMonthlyTitle'),
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _SubscriptionOptionCard(
                        title: context.t('subscriptionYearlyTitle'),
                        onTap: () {},
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {},
                        child: Text(context.t('subscriptionRestoreButton')),
                      ),
                    ] else
                      FilledButton(
                        onPressed: _checking ? null : _retryConnection,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: _checking
                            ? Text(context.t('subscriptionPurchasePending'))
                            : Text(context.t('subscriptionRetryButton')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionOptionCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SubscriptionOptionCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: FilledButton(
          onPressed: onTap,
          child: Text(context.t('subscriptionPurchaseButton')),
        ),
      ),
    );
  }
}
