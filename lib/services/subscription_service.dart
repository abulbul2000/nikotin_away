import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_state.dart';
import 'storage_service.dart';

enum AccessDecision {
  allowed,
  needsSurveyFirst,
  showGate,
  needsConnectionCheck,
}

enum PurchaseOutcome { success, cancelled, pending, failed }

class SubscriptionService {
  SubscriptionService({StorageService? storageService, bool? allowDebugAccess})
    : _storage = storageService ?? StorageService(),
      _allowDebugAccess = allowDebugAccess ?? kDebugMode;

  final StorageService _storage;
  final bool _allowDebugAccess;

  static const Duration offlineGraceDuration = Duration(days: 3);
  static const Duration trialDuration = Duration(days: 14);

  static const String starterProductId = 'no_smoke_starter';
  static const String plusProductId = 'no_smoke_plus';
  static const String proProductId = 'no_smoke_pro';
  static const List<String> productIds = [
    starterProductId,
    plusProductId,
    proProductId,
  ];

  static String planForProductId(String productId) {
    switch (productId) {
      case starterProductId:
        return 'starter';
      case plusProductId:
        return 'plus';
      case proProductId:
        return 'pro';
      default:
        return 'unknown';
    }
  }

  static String productTitle(String productId) {
    switch (productId) {
      case starterProductId:
        return 'Starter';
      case plusProductId:
        return 'Plus';
      case proProductId:
        return 'Pro';
      default:
        return 'Premium';
    }
  }

  Future<SubscriptionState?> loadState() => _storage.loadSubscriptionState();

  Future<AccessDecision> resolveAccess({
    required bool hasCompletedInitialSurvey,
  }) async {
    if (!hasCompletedInitialSurvey) {
      return AccessDecision.needsSurveyFirst;
    }

    // `flutter run` is the local development build. It is intentionally free
    // for the developer; production Cloud Functions still enforce purchases.
    if (_allowDebugAccess) return AccessDecision.allowed;

    final state = await _storage.loadSubscriptionState();
    final trustedNow = await _trustedNow(state);

    if (state?.status == SubscriptionStatus.trial) {
      return isTrialActive(state, now: trustedNow)
          ? AccessDecision.allowed
          : AccessDecision.showGate;
    }

    if (state?.status == SubscriptionStatus.active ||
        state?.status == SubscriptionStatus.grace) {
      final lastVerifiedAt = state?.lastVerifiedAt;
      if (lastVerifiedAt != null &&
          trustedNow.isBefore(lastVerifiedAt.add(offlineGraceDuration))) {
        return AccessDecision.allowed;
      }
      return AccessDecision.needsConnectionCheck;
    }

    return AccessDecision.showGate;
  }

  /// Whether [state] is a trial that hasn't run past [trialDuration] yet, as
  /// of [now] (defaults to [DateTime.now()] — callers evaluating access
  /// should pass the [_trustedNow]-adjusted value instead so a rolled-back
  /// device clock can't replay the trial window). Exposed separately from
  /// [resolveAccess] so [FeatureAccess] can tell a trial-granted "allowed"
  /// apart from a paid one — the trial unlocks the app but not the AI
  /// mentor, which spends the developer's own API budget.
  static bool isTrialActive(SubscriptionState? state, {DateTime? now}) {
    final startedAt = state?.trialStartedAt;
    if (startedAt == null) return false;
    return (now ?? DateTime.now()).isBefore(startedAt.add(trialDuration));
  }

  /// Returns a "now" that never moves backward relative to what this device
  /// has already recorded, and persists the new high-water mark. A user can
  /// set their system clock back to make an elapsed trial/grace window
  /// (measured as `now - startedAt`) look unelapsed again — comparing
  /// against `state.maxObservedAt` instead of a bare `DateTime.now()` means
  /// a rolled-back clock simply freezes the window instead of extending it.
  /// This is a client-side deterrent only; nothing here is trusted by the
  /// server (aiChat enforces its own subscription check independently).
  Future<DateTime> _trustedNow(SubscriptionState? state) async {
    final now = DateTime.now();
    final maxObserved = state?.maxObservedAt;
    final trustedNow = (maxObserved != null && now.isBefore(maxObserved))
        ? maxObserved
        : now;

    if (maxObserved == null || now.isAfter(maxObserved)) {
      final existing =
          state ??
          SubscriptionState(status: SubscriptionStatus.none, updatedAt: now);
      await _storage.saveSubscriptionState(
        existing.copyWith(maxObservedAt: now),
      );
    }

    return trustedNow;
  }

  Future<List<ProductDetails>> loadProducts() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return const [];
    final response = await InAppPurchase.instance.queryProductDetails(
      productIds.toSet(),
    );
    if (response.error != null) return const [];
    return response.productDetails;
  }

  Future<bool> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<bool> restore() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return false;
    await InAppPurchase.instance.restorePurchases();
    return true;
  }

  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

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
