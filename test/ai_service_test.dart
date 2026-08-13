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
}
