import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription_state.dart';
import 'language_service.dart';
import 'storage_service.dart';

class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiSubscriptionRequiredException implements Exception {
  const AiSubscriptionRequiredException();
}

class AiAuthRequiredException implements Exception {
  const AiAuthRequiredException();
}

class AiDailyLimitReachedException implements Exception {
  const AiDailyLimitReachedException();
}

class AiChatTurn {
  const AiChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiAction {
  const AiAction({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;
}

/// Maps a `set_coach_mode` tool call's `preference` argument to whether
/// `duration_barrier_enabled` should end up on.
///
/// `duration_barrier_preference` ('like'/'neutral'/'dislike' as a
/// barrier-difficulty knob) no longer exists — see coach_mode_page.dart's
/// doc comment — only on/off remains. 'dislike' used to mean "make it
/// easier" while staying on; now that there is no difficulty axis left to
/// soften, it means the same thing the "sevmedim/kötü/beğenmedim" voice
/// intent's own confirmation text already promises the user: off. Only
/// 'like'/'neutral' still mean on.
bool coachModeShouldBeEnabled(String preference) =>
    !const ['off', 'dislike'].contains(preference);

class AiChatResult {
  const AiChatResult({required this.reply, this.action});

  final String reply;
  final AiAction? action;
}

// Keep the client-side validation aligned with functions/auth.js.
const int _maxHistoryTurns = 20;
const int _maxTurnCharacters = 8000;
const int _maxTotalHistoryCharacters = 16000;
const int _maxMedicationNameCharacters = 100;
const int _maxMedicationTimes = 8;

/// Languages the AI is expected to reply in. Anything outside this list is
/// treated as a malformed response and hidden from the user — the AI may
/// still reply in these languages even when the user's app language differs,
/// but that is handled server-side; this list is a safety net for the UI.
const Set<String> _allowedResponseLanguages = {
  'tr',
  'en',
  'de',
  'ar',
  'fr',
  'es',
  'pt',
  'it',
  'pl',
  'ru',
  'ja',
  'zh',
  'ko',
  'hi',
};

const Set<String> _allowedRoles = {'user', 'assistant'};
const Set<String> _allowedActions = {
  'set_coach_mode',
  'set_medication_times',
  'set_permission',
};
const Set<String> _allowedCoachPreferences = {
  'like',
  'neutral',
  'dislike',
  'off',
};
const Set<String> _allowedCoachFrequencies = {'az', 'orta', 'cok'};
const Set<String> _allowedPermissions = {
  'microphone',
  'location',
  'activityRecognition',
  'health',
  'usageAccess',
};

Future<void> _syncServerTrialStart(DateTime serverTrialStartedAt) async {
  final storage = StorageService();
  final existing = await storage.loadSubscriptionState();
  if (existing?.trialStartedAt == serverTrialStartedAt) return;

  final now = DateTime.now();
  await storage.saveSubscriptionState(
    (existing ??
            SubscriptionState(status: SubscriptionStatus.trial, updatedAt: now))
        .copyWith(trialStartedAt: serverTrialStartedAt, updatedAt: now),
  );
}

void _validateHistory(List<AiChatTurn> history) {
  if (history.isEmpty) {
    throw const AiServiceException('History is empty');
  }
  if (history.length > _maxHistoryTurns) {
    throw const AiServiceException('History is too long');
  }

  var totalCharacters = 0;
  for (final turn in history) {
    if (!_allowedRoles.contains(turn.role)) {
      throw const AiServiceException('Invalid chat role');
    }
    final content = turn.content.trim();
    if (content.isEmpty || content.length > _maxTurnCharacters) {
      throw const AiServiceException('Invalid chat message length');
    }
    totalCharacters += content.length;
  }
  if (totalCharacters > _maxTotalHistoryCharacters) {
    throw const AiServiceException('Chat history is too large');
  }
}

Map<String, dynamic> _stringKeyedMap(dynamic value, String fieldName) {
  if (value is! Map) {
    throw AiServiceException('Invalid $fieldName');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

void _validateActionArguments(String name, Map<String, dynamic> args) {
  switch (name) {
    case 'set_coach_mode':
      final preference = args['preference'];
      final frequency = args['frequency'];
      if (preference is! String ||
          !_allowedCoachPreferences.contains(preference)) {
        throw const AiServiceException('Invalid coach mode action');
      }
      if (frequency != null &&
          (frequency is! String ||
              !_allowedCoachFrequencies.contains(frequency))) {
        throw const AiServiceException('Invalid coach frequency action');
      }
      return;

    case 'set_medication_times':
      final medicationName = args['medicationName'];
      final times = args['times'];
      if (medicationName is! String ||
          medicationName.trim().isEmpty ||
          medicationName.length > _maxMedicationNameCharacters ||
          times is! List ||
          times.isEmpty ||
          times.length > _maxMedicationTimes) {
        throw const AiServiceException('Invalid medication time action');
      }
      final timePattern = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
      for (final time in times) {
        if (time is! String || !timePattern.hasMatch(time)) {
          throw const AiServiceException('Invalid medication time format');
        }
      }
      return;

    case 'set_permission':
      final permission = args['permission'];
      if (permission is! String || !_allowedPermissions.contains(permission)) {
        throw const AiServiceException('Invalid permission action');
      }
      return;

    default:
      throw const AiServiceException('Unsupported AI action');
  }
}

AiAction? _parseAndValidateAction(dynamic rawAction) {
  if (rawAction == null) return null;

  final actionMap = _stringKeyedMap(rawAction, 'action');
  final name = actionMap['name'];
  if (name is! String || !_allowedActions.contains(name)) {
    throw const AiServiceException('Unsupported AI action');
  }

  final arguments = _stringKeyedMap(
    actionMap['arguments'] ?? <String, dynamic>{},
    'action arguments',
  );
  _validateActionArguments(name, arguments);
  return AiAction(name: name, arguments: arguments);
}

Future<AiChatResult> sendMessageToAI(List<AiChatTurn> history) async {
  _validateHistory(history);

  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('aiChat');
    final result = await callable.call<Map<String, dynamic>>({
      'history': history
          .map((turn) => {'role': turn.role, 'content': turn.content.trim()})
          .toList(),
      'language': await _resolveAppLanguage(),
      'behaviorContext': await _resolveBehaviorContext(),
      // Only the separate development Firebase project accepts this flag.
      // Release builds always send false and require a verified Play purchase.
      'debugClient': kDebugMode,
    });

    final reply = result.data['reply'] as String? ?? '';
    if (reply.length > _maxTurnCharacters) {
      throw const AiServiceException('AI reply is too long');
    }
    final responseLanguage = result.data['language'] as String?;
    if (responseLanguage != null &&
        !_allowedResponseLanguages.contains(responseLanguage)) {
      throw const AiServiceException('AI responded in an unsupported language');
    }

    final action = _parseAndValidateAction(result.data['action']);
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

/// Kept as a separate pure function so it can be unit-tested without Firebase.
Exception mapAiFunctionsExceptionForTest(FirebaseFunctionsException e) =>
    mapAiFunctionsException(e);

/// Resolves the user's preferred app language code. Never throws — falls back
/// to English when the preference cannot be read, since English is always
/// supported by the AI backend.
Future<String> _resolveAppLanguage() async {
  try {
    return await LanguageService.loadSelectedLanguageCode();
  } catch (_) {
    return 'en';
  }
}

/// A compact summary of what BehaviorEngine has already learned about this
/// user — risky triggers/hours, the predicted next risk window, weekly risk
/// level — so the AI coach's advice can be grounded in the same behavioral
/// signals the rest of the app (tasks, notifications, geofencing) already
/// acts on, instead of only ever seeing the current chat turn. Never
/// throws: a coaching context this is missing is strictly worse than a
/// server error blocking the whole conversation, so any failure here just
/// falls back to an empty context and the chat proceeds without it.
Future<Map<String, dynamic>> _resolveBehaviorContext() async {
  try {
    final dashboard = await StorageService().loadBehaviorDashboard();
    return {
      'riskyTriggers': dashboard.riskyTriggers,
      'riskyHours': dashboard.riskyHours,
      'weeklySurveyRiskLevel': dashboard.weeklySurveyRiskLevel,
      'predictedRiskWindow': dashboard.predictedRiskWindow,
      'predictedTrigger': dashboard.predictedTrigger,
    };
  } catch (_) {
    return const {};
  }
}
