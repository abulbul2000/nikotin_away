import '../models/subscription_state.dart';
import 'subscription_service.dart';

/// Every screen/capability that can be gated behind a subscription. Kept as
/// an enum (not a raw string) so call sites get compiler-checked names
/// instead of typo-prone string literals.
enum PremiumFeature {
  aiMentor,
  adaptiveTasks,
  breathCoughTests,
  locationIntelligence,
  sleepIntelligence,
  wearableData,
}

/// Single decision point for "does this feature require an active
/// trial/subscription right now" — pages call [canAccess] instead of
/// re-deriving the free/premium split themselves, so it lives in exactly
/// one place. Everything NOT listed in [PremiumFeature] (streak, savings,
/// health recovery timeline, badges, history/export, settings, permission
/// center, data deletion, cloud backup) is free and never gated by this
/// class at all — pages for those features simply never call it.
///
/// Deliberately re-derives [AccessDecision] itself (via
/// [SubscriptionService.resolveAccess]) rather than requiring every call
/// site to compute and pass it in — this is the feature-gate entry point,
/// [SubscriptionService] stays the source of truth for the underlying
/// trial/subscription state.
class FeatureAccess {
  FeatureAccess({SubscriptionService? subscriptionService})
    : _subscriptionService = subscriptionService ?? SubscriptionService();

  final SubscriptionService _subscriptionService;

  /// True for every [PremiumFeature] today — there is no per-feature
  /// entitlement split (e.g. "AI mentor only" vs "full premium"), a single
  /// active trial/subscription unlocks all of them. If that ever changes,
  /// this is the one place to add per-feature logic.
  bool requiresSubscription(PremiumFeature feature) => true;

  /// Whether [feature] is still gated during the 14-day trial. Only
  /// [PremiumFeature.aiMentor] is — the AI chat spends the developer's own
  /// shared LLM API budget per message, so trial users get the rest of the
  /// app (adaptive tasks, breath/cough tests, location/sleep intelligence)
  /// but not that.
  bool requiresPaidSubscription(PremiumFeature feature) =>
      feature == PremiumFeature.aiMentor;

  /// Whether the current user can use [feature] right now. Onboarding is
  /// assumed complete by the time any premium feature's page is reachable
  /// (the survey gate runs before HomePage), so this always passes
  /// `hasCompletedInitialSurvey: true` to [SubscriptionService.resolveAccess]
  /// — a caller reachable from HomePage has necessarily finished it.
  Future<bool> canAccess(PremiumFeature feature) async {
    if (!requiresSubscription(feature)) {
      return true;
    }
    final decision = await _subscriptionService.resolveAccess(
      hasCompletedInitialSurvey: true,
    );
    if (decision != AccessDecision.allowed) {
      return false;
    }
    if (!requiresPaidSubscription(feature)) {
      return true;
    }
    final state = await _subscriptionService.loadState();
    return state?.status != SubscriptionStatus.trial;
  }
}
