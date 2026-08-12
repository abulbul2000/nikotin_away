import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_state.dart';
import 'storage_service.dart';

enum AccessDecision {
  /// User is inside the 14-day trial, or has a currently-valid subscription
  /// (verified fresh, or cached within the offline grace period).
  allowed,

  /// Onboarding's initial survey hasn't been completed yet — the trial
  /// clock hasn't started, so there is nothing to gate on yet.
  needsSurveyFirst,

  /// Trial expired and there is no valid subscription on record.
  showGate,

  /// A subscription was active as of the last check, but the cache is
  /// older than [SubscriptionService.offlineGraceDuration] and a fresh
  /// server check hasn't been possible — the app can't tell "still valid"
  /// from "silently expired while offline" anymore.
  needsConnectionCheck,
}

/// Outcome of a purchase (or restore) attempt, for callers that need to
/// show something more specific than "it worked or it didn't" — e.g.
/// [SubscriptionGatePage] distinguishing a user-cancelled dialog (say
/// nothing) from a store/network failure (show an error).
enum PurchaseOutcome { success, cancelled, pending, failed }

/// Single decision point for "can the user be in the app right now" —
/// called from [SplashPage] on launch and from the app-resume lifecycle
/// hook, so both paths agree on the same rules instead of drifting apart.
///
/// Also owns the actual Play Billing purchase flow: [products],
/// [buy] and [restore] wrap `in_app_purchase`, and every completed
/// purchase is re-verified against Google via the `verifySubscription`
/// Cloud Function (see `functions/subscription.js`) before it's trusted —
/// the Play purchase stream alone isn't proof the token is still valid.
class SubscriptionService {
  SubscriptionService({StorageService? storageService})
    : _storage = storageService ?? StorageService();

  final StorageService _storage;

  static const Duration trialDuration = Duration(days: 14);

  /// How long a cached `active` verification is trusted without a fresh
  /// server check. Short enough that a silently-cancelled subscription
  /// doesn't keep unlocking the AI mentor (the actual cost driver) for
  /// weeks; long enough that a user offline for a few days (flight,
  /// no signal) isn't locked out over it. See the subscription plan doc
  /// for the full trade-off.
  static const Duration offlineGraceDuration = Duration(days: 3);

  /// Product IDs as they must be configured in Play Console → Monetize →
  /// Subscriptions. Changing these strings after the app ships means the
  /// old IDs become orphaned and existing subscribers' entitlements can't
  /// be matched, so treat them as fixed once the app is live.
  static const String monthlyProductId = 'no_smoke_monthly';
  static const String yearlyProductId = 'no_smoke_yearly';
  static const List<String> productIds = [monthlyProductId, yearlyProductId];

  Future<AccessDecision> resolveAccess({
    required bool hasCompletedInitialSurvey,
  }) async {
    if (!hasCompletedInitialSurvey) {
      return AccessDecision.needsSurveyFirst;
    }

    final state = await _storage.loadSubscriptionState();
    final now = DateTime.now();

    final trialStartedAt = state?.trialStartedAt;
    if (trialStartedAt != null &&
        now.isBefore(trialStartedAt.add(trialDuration))) {
      return AccessDecision.allowed;
    }

    if (state?.status == SubscriptionStatus.active ||
        state?.status == SubscriptionStatus.grace) {
      final lastVerifiedAt = state?.lastVerifiedAt;
      if (lastVerifiedAt != null &&
          now.isBefore(lastVerifiedAt.add(offlineGraceDuration))) {
        return AccessDecision.allowed;
      }
      return AccessDecision.needsConnectionCheck;
    }

    return AccessDecision.showGate;
  }

  /// Fetches live Play Store listings (localized price/currency) for
  /// [productIds]. Returns an empty list if the store is unreachable or
  /// unavailable (e.g. no Play Store on the device) — callers fall back to
  /// disabling the purchase buttons rather than showing a stale price.
  Future<List<ProductDetails>> loadProducts() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      return const [];
    }
    final response = await InAppPurchase.instance.queryProductDetails(
      productIds.toSet(),
    );
    if (response.error != null) {
      return const [];
    }
    return response.productDetails;
  }

  /// Starts the Play Billing purchase sheet for [product]. The actual
  /// entitlement change happens asynchronously via [purchaseStream] — this
  /// only kicks off the flow and reports whether the *request itself*
  /// could be made (store reachable, sheet opened), not whether the
  /// purchase succeeded.
  Future<bool> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<bool> restore() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      return false;
    }
    await InAppPurchase.instance.restorePurchases();
    return true;
  }

  /// Raw purchase-update stream from the platform billing client. Callers
  /// (currently [SubscriptionGatePage]) listen to this to know when to call
  /// [handlePurchase] and to surface [PurchaseOutcome] to the user; kept as
  /// a passthrough rather than wrapped so callers can still use
  /// `IAPError`/`PurchaseStatus` directly.
  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

  /// Verifies [purchase] against Google (never trusting the on-device
  /// purchase object alone — see `functions/subscription.js`), persists the
  /// result to `subscription_state`, and completes the platform purchase so
  /// Play stops redelivering it on every app start. Returns the
  /// [PurchaseOutcome] to show the user.
  Future<PurchaseOutcome> handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return PurchaseOutcome.pending;
      case PurchaseStatus.canceled:
        return PurchaseOutcome.cancelled;
      case PurchaseStatus.error:
        return PurchaseOutcome.failed;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }

    final now = DateTime.now();
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('verifySubscription');
      final result = await callable.call<Map<String, dynamic>>({
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
      });
      final isActive = result.data['isActive'] as bool? ?? false;
      final expiryMillis = result.data['expiryTimeMillis'] as int?;
      final autoRenewing = result.data['autoRenewing'] as bool? ?? false;

      final existing = await _storage.loadSubscriptionState();
      await _storage.saveSubscriptionState(
        (existing ??
                SubscriptionState(
                  status: SubscriptionStatus.none,
                  updatedAt: now,
                ))
            .copyWith(
              status: isActive
                  ? SubscriptionStatus.active
                  : SubscriptionStatus.expired,
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
              purchaseOrderId: purchase.purchaseID,
              expiryTime: expiryMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(expiryMillis)
                  : null,
              lastVerifiedAt: now,
              lastVerificationAttemptAt: now,
              autoRenewing: autoRenewing,
              updatedAt: now,
            ),
      );

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }

      return isActive ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } catch (_) {
      // Network/server failure verifying a purchase Play already reports as
      // completed: don't complete the platform purchase (Play will
      // redeliver it on the stream so verification can be retried), and
      // don't write a subscription_state row claiming a status we couldn't
      // actually confirm.
      final existing = await _storage.loadSubscriptionState();
      if (existing != null) {
        await _storage.saveSubscriptionState(
          existing.copyWith(lastVerificationAttemptAt: now, updatedAt: now),
        );
      }
      return PurchaseOutcome.failed;
    }
  }
}
