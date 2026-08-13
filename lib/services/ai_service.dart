import 'package:cloud_functions/cloud_functions.dart';

import '../models/subscription_state.dart';
import 'storage_service.dart';

class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The server rejected the request because the caller isn't inside the
/// trial window and has no active subscription. Distinct from
/// [AiServiceException] so callers (AIChatPage) can route straight to
/// SubscriptionGatePage instead of showing a generic error snackbar — this
/// is the edge case where the client-side gate should already have caught
/// it (trial/subscription lapsed in the background before the next resume
/// check ran), not a normal failure.
class AiSubscriptionRequiredException implements Exception {
  const AiSubscriptionRequiredException();
}

/// The server rejected the request because App Check/anonymous auth hasn't
/// completed yet (see main.dart — both are best-effort and non-blocking, so
/// there's a narrow window right after a cold start with no network where a
/// callable can race ahead of them). Callers should surface this as "try
/// again in a moment" rather than routing to the subscription gate.
class AiAuthRequiredException implements Exception {
  const AiAuthRequiredException();
}

/// The server rejected the request because the caller already sent
/// [DAILY_MESSAGE_LIMIT] (see functions/index.js) messages today. Distinct
/// from [AiSubscriptionRequiredException] so callers can show "come back
/// tomorrow" instead of steering an already-paying user to the purchase
/// screen.
class AiDailyLimitReachedException implements Exception {
  const AiDailyLimitReachedException();
}

class AiChatTurn {
  const AiChatTurn({required this.role, required this.content});

  final String role; // 'user' or 'assistant'
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiAction {
  const AiAction({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;
}

class AiChatResult {
  const AiChatResult({required this.reply, this.action});

  final String reply;
  final AiAction? action;
}

/// Reconciles the local subscription_state cache with the
/// server-authoritative trial start (see functions/index.js's
/// getOrCreateUserDoc): the server value always wins. This only ever moves
/// the cached date to match the server — [SubscriptionService.resolveAccess]
/// keeps reading trialStartedAt from local storage so the offline grace
/// window still works, it just now reads a server-synced value instead of
/// a purely client-set one.
Future<void> _syncServerTrialStart(DateTime serverTrialStartedAt) async {
  final storage = StorageService();
  final existing = await storage.loadSubscriptionState();
  if (existing?.trialStartedAt == serverTrialStartedAt) {
    return;
  }
  final now = DateTime.now();
  await storage.saveSubscriptionState(
    (existing ??
            SubscriptionState(status: SubscriptionStatus.trial, updatedAt: now))
        .copyWith(trialStartedAt: serverTrialStartedAt, updatedAt: now),
  );
}

Future<AiChatResult> sendMessageToAI(List<AiChatTurn> history) async {
  if (history.isEmpty) {
    throw const AiServiceException('History is empty');
  }

  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('aiChat');
    final result = await callable.call<Map<String, dynamic>>({
      'history': history.map((t) => t.toJson()).toList(),
    });

    final reply = result.data['reply'] as String? ?? '';
    final rawAction = result.data['action'] as Map<dynamic, dynamic>?;
    AiAction? action;
    if (rawAction != null && rawAction['name'] is String) {
      final rawArgs = rawAction['arguments'] as Map<dynamic, dynamic>? ?? {};
      action = AiAction(
        name: rawAction['name'] as String,
        arguments: rawArgs.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    if (reply.isEmpty && action == null) {
      throw const AiServiceException('Empty response from AI');
    }

    final trialStartedAtMs = result.data['trialStartedAtMs'] as int?;
    if (trialStartedAtMs != null) {
      await _syncServerTrialStart(
        DateTime.fromMillisecondsSinceEpoch(trialStartedAtMs),
      );
    }

    return AiChatResult(reply: reply, action: action);
  } on FirebaseFunctionsException catch (e) {
    throw mapAiFunctionsException(e);
  }
}

/// Maps an `aiChat`/`verifySubscription` [FirebaseFunctionsException] code
/// (see functions/index.js's `requireAuth`, `hasAiAccess` and
/// `consumeDailyMessageQuota`) to the exception type callers actually branch
/// on. Pulled out of [sendMessageToAI] — no I/O, so it's testable without a
/// real Firebase backend (see test/ai_service_test.dart).
Exception mapAiFunctionsException(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'permission-denied':
      return const AiSubscriptionRequiredException();
    case 'unauthenticated':
      return const AiAuthRequiredException();
    case 'resource-exhausted':
      return const AiDailyLimitReachedException();
    default:
      return AiServiceException(e.message ?? e.code);
  }
}
