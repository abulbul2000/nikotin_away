import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/ai_service.dart';

FirebaseFunctionsException _exceptionWithCode(String code) =>
    FirebaseFunctionsException(message: 'test', code: code);

void main() {
  group('mapAiFunctionsException', () {
    test('unauthenticated maps to AiAuthRequiredException', () {
      // Server-side: functions/auth.js's requireAuth throws this when
      // request.auth is missing — the case an unauthenticated caller (no
      // App Check/anonymous-auth token) hits.
      expect(
        mapAiFunctionsException(_exceptionWithCode('unauthenticated')),
        isA<AiAuthRequiredException>(),
      );
    });

    test('permission-denied maps to AiSubscriptionRequiredException', () {
      expect(
        mapAiFunctionsException(_exceptionWithCode('permission-denied')),
        isA<AiSubscriptionRequiredException>(),
      );
    });

    test('resource-exhausted maps to AiDailyLimitReachedException', () {
      expect(
        mapAiFunctionsException(_exceptionWithCode('resource-exhausted')),
        isA<AiDailyLimitReachedException>(),
      );
    });

    test('unrecognized codes fall back to AiServiceException', () {
      expect(
        mapAiFunctionsException(_exceptionWithCode('internal')),
        isA<AiServiceException>(),
      );
    });
  });

  group('coachModeShouldBeEnabled', () {
    // Regression coverage: 'dislike' used to fall through to the "on"
    // branch in ai_chat_page.dart's _applyCoachMode (only a literal 'off'
    // turned duration_barrier_enabled to '0'). The "koç modunu sevmedim /
    // kötü / beğenmedim / nefret" voice intent tells the user "Koç modu
    // kapatılacak" (coach mode will be turned off) and sends
    // preference: 'dislike' — so confirming that dialog silently left (or
    // turned) coach mode on, the opposite of what the user just agreed to.
    test('off means disabled', () {
      expect(coachModeShouldBeEnabled('off'), isFalse);
    });

    test('dislike means disabled, same as off', () {
      expect(coachModeShouldBeEnabled('dislike'), isFalse);
    });

    test('like means enabled', () {
      expect(coachModeShouldBeEnabled('like'), isTrue);
    });

    test('neutral means enabled', () {
      expect(coachModeShouldBeEnabled('neutral'), isTrue);
    });
  });
}
