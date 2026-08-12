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

/// Single decision point for "can the user be in the app right now" —
/// called from [SplashPage] on launch and from the app-resume lifecycle
/// hook, so both paths agree on the same rules instead of drifting apart.
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
}
