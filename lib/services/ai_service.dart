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

Future<Map<String, dynamic>> _buildSubscriptionProof() async {
  final state = await StorageService().loadSubscriptionState();
  if (state == null) return {};
  if (state.status == SubscriptionStatus.active ||
      state.status == SubscriptionStatus.grace) {
    if (state.productId != null && state.purchaseToken != null) {
      return {
        'productId': state.productId,
        'purchaseToken': state.purchaseToken,
      };
    }
  }
  if (state.trialStartedAt != null) {
    return {'trialStartedAt': state.trialStartedAt!.toIso8601String()};
  }
  return {};
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
      'subscriptionProof': await _buildSubscriptionProof(),
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
    return AiChatResult(reply: reply, action: action);
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'permission-denied') {
      throw const AiSubscriptionRequiredException();
    }
    throw AiServiceException(e.message ?? e.code);
  }
}
