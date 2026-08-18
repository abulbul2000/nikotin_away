import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/app_texts.dart';
import '../core/home_seed_resolver.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'home_page.dart';

/// Shown once the 14-day trial has ended and no valid subscription is on
/// record — [AccessDecision.showGate] / [AccessDecision.needsConnectionCheck]
/// both route here (see SplashPage/[NoSmokeApp.didChangeAppLifecycleState]
/// for the two places that do). No longer a hard lock: "Continue for free"
/// always gets the user back into HomePage — free features stay reachable
/// forever, only [PremiumFeature]s (see feature_access.dart) are gated, and
/// each of those shows its own in-place upgrade prompt rather than routing
/// here as a full-screen wall.
class SubscriptionGatePage extends StatefulWidget {
  final bool needsConnectionOnly;

  /// Overridable for tests, which have no real Play Store to talk to —
  /// production call sites always use the default (a real
  /// [SubscriptionService] backed by `in_app_purchase`).
  final SubscriptionService? subscriptionService;

  const SubscriptionGatePage({
    super.key,
    this.needsConnectionOnly = false,
    this.subscriptionService,
  });

  @override
  State<SubscriptionGatePage> createState() => _SubscriptionGatePageState();
}

class _SubscriptionGatePageState extends State<SubscriptionGatePage> {
  late final SubscriptionService _subscriptionService =
      widget.subscriptionService ?? SubscriptionService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = [];
  bool _checking = false;
  bool _loadingProducts = false;
  bool _purchaseInFlight = false;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _subscriptionService.purchaseStream.listen(
      _onPurchaseUpdates,
    );
    if (!widget.needsConnectionOnly) {
      unawaited(_loadProducts());
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final products = await _subscriptionService.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loadingProducts = false;
    });
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final outcome = await _subscriptionService.handlePurchase(purchase);
      if (!mounted) return;
      if (outcome == PurchaseOutcome.pending) {
        continue;
      }
      setState(() => _purchaseInFlight = false);
      if (outcome == PurchaseOutcome.success) {
        await _leaveGate();
        return;
      }
      if (outcome == PurchaseOutcome.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('subscriptionPurchaseFailed'))),
        );
      }
      // Cancelled: silently do nothing, same as any other store purchase
      // dialog the user backed out of.
    }
  }

  /// Leaves the gate after it's no longer needed — a successful purchase/
  /// restore, a connectivity check resolving to [AccessDecision.allowed],
  /// or the user choosing to continue on the free tier. Pops back to
  /// whatever pushed this page when there is one (e.g. AIChatPage routing
  /// here mid-session); when this page was reached via `pushReplacement`/
  /// `pushAndRemoveUntil` (SplashPage, the app-resume hook) there's nothing
  /// to pop back to, so it goes to HomePage directly instead.
  Future<void> _leaveGate() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final storage = StorageService();
    final records = await storage.loadSurveyHistory();
    if (!mounted) return;
    final seed = HomeSeedResolver.fromRecords(records);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(
          name: seed.name,
          riskScore: seed.riskScore,
          riskLevel: seed.riskLevel,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _buy(ProductDetails product) async {
    if (_purchaseInFlight) return;
    setState(() => _purchaseInFlight = true);
    final started = await _subscriptionService.buy(product);
    if (!started && mounted) {
      setState(() => _purchaseInFlight = false);
    }
  }

  Future<void> _restore() async {
    if (_purchaseInFlight) return;
    setState(() => _purchaseInFlight = true);
    final started = await _subscriptionService.restore();
    if (!started && mounted) {
      setState(() => _purchaseInFlight = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('subscriptionPurchaseFailed'))),
      );
    }
  }

  Future<void> _retryConnection() async {
    setState(() => _checking = true);
    final decision = await _subscriptionService.resolveAccess(
      hasCompletedInitialSurvey: true,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    if (decision == AccessDecision.allowed) {
      await _leaveGate();
    }
  }

  ProductDetails? _productFor(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
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
                    if (_loadingProducts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_products.isEmpty)
                      Text(
                        context.t('subscriptionStoreUnavailable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 14,
                        ),
                      )
                    else ...[
                      for (final id in SubscriptionService.productIds)
                        if (_productFor(id) case final product?) ...[
                          _SubscriptionOptionCard(
                            title: SubscriptionService.productTitle(id),
                            price: product.price,
                            enabled: !_purchaseInFlight,
                            onTap: () => _buy(product),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _purchaseInFlight ? null : _restore,
                      child: Text(context.t('subscriptionRestoreButton')),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _checking ? null : _retryConnection,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: _checking
                          ? Text(context.t('subscriptionPurchasePending'))
                          : Text(context.t('subscriptionRetryButton')),
                    ),
                    const SizedBox(height: 8),
                    // A real subscriber who has been offline past the grace
                    // period (see SubscriptionService.offlineGraceDuration)
                    // gets stuck on this screen forever if _retryConnection
                    // is the only option — it just re-reads the locally
                    // cached (stale) state. Restore re-asks Play directly,
                    // which re-verifies and updates that cache regardless
                    // of how long it's been.
                    TextButton(
                      onPressed: _purchaseInFlight ? null : _restore,
                      child: Text(context.t('subscriptionRestoreButton')),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('subscription_gate_continue_free'),
                    onPressed: _purchaseInFlight ? null : _leaveGate,
                    child: Text(context.t('subscriptionContinueFreeButton')),
                  ),
                ],
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
  final String price;
  final bool enabled;
  final VoidCallback onTap;

  const _SubscriptionOptionCard({
    required this.title,
    required this.price,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(price),
        trailing: FilledButton(
          onPressed: enabled ? onTap : null,
          child: Text(context.t('subscriptionPurchaseButton')),
        ),
      ),
    );
  }
}
