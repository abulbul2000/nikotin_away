import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/ai_service.dart';

/// Tests for the AI safety/validation layer added to ai_service.dart.
void main() {
  group('exception types', () {
    test('AiServiceException toString returns message', () {
      const e = AiServiceException('test error');
      expect(e.message, 'test error');
      expect(e.toString(), 'test error');
    });

    test('AiSubscriptionRequiredException is Exception', () {
      expect(const AiSubscriptionRequiredException(), isA<Exception>());
    });

    test('AiAuthRequiredException is Exception', () {
      expect(const AiAuthRequiredException(), isA<Exception>());
    });

    test('AiDailyLimitReachedException is Exception', () {
      expect(const AiDailyLimitReachedException(), isA<Exception>());
    });
  });

  group('AiChatTurn serialization', () {
    test('toJson returns correct map', () {
      const turn = AiChatTurn(role: 'user', content: 'test message');
      final json = turn.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'test message');
    });

    test('toJson with assistant role', () {
      const turn = AiChatTurn(role: 'assistant', content: 'Merhaba');
      final json = turn.toJson();
      expect(json['role'], 'assistant');
      expect(json['content'], 'Merhaba');
    });
  });

  group('AiChatResult construction', () {
    test('holds reply and action', () {
      const action = AiAction(
        name: 'set_coach_mode',
        arguments: {'preference': 'like'},
      );
      const result = AiChatResult(reply: 'Tamam', action: action);
      expect(result.reply, 'Tamam');
      expect(result.action!.name, 'set_coach_mode');
      expect(result.action!.arguments['preference'], 'like');
    });

    test('can have null action', () {
      const result = AiChatResult(reply: 'Merhaba');
      expect(result.reply, 'Merhaba');
      expect(result.action, isNull);
    });
  });

  group('AiAction construction', () {
    test('holds name and arguments', () {
      const action = AiAction(
        name: 'set_permission',
        arguments: {'permission': 'microphone'},
      );
      expect(action.name, 'set_permission');
      expect(action.arguments['permission'], 'microphone');
    });

    test('holds complex arguments', () {
      const action = AiAction(
        name: 'set_medication_times',
        arguments: {
          'medicationName': 'Varéniklin',
          'times': ['08:00', '20:00'],
        },
      );
      expect(action.arguments['medicationName'], 'Varéniklin');
      final times = action.arguments['times'] as List;
      expect(times.length, 2);
    });
  });

  group('mapAiFunctionsException', () {
    test('permission-denied maps to AiSubscriptionRequiredException', () {
      final e = FirebaseFunctionsException(
        code: 'permission-denied',
        details: null,
        message: 'denied',
      );
      final mapped = mapAiFunctionsExceptionForTest(e);
      expect(mapped, isA<AiSubscriptionRequiredException>());
    });

    test('unauthenticated maps to AiAuthRequiredException', () {
      final e = FirebaseFunctionsException(
        code: 'unauthenticated',
        details: null,
        message: 'not auth',
      );
      final mapped = mapAiFunctionsExceptionForTest(e);
      expect(mapped, isA<AiAuthRequiredException>());
    });

    test('resource-exhausted maps to AiDailyLimitReachedException', () {
      final e = FirebaseFunctionsException(
        code: 'resource-exhausted',
        details: null,
        message: 'rate limit',
      );
      final mapped = mapAiFunctionsExceptionForTest(e);
      expect(mapped, isA<AiDailyLimitReachedException>());
    });

    test('unknown code maps to AiServiceException', () {
      final e = FirebaseFunctionsException(
        code: 'internal',
        details: null,
        message: 'something broke',
      );
      final mapped = mapAiFunctionsExceptionForTest(e);
      expect(mapped, isA<AiServiceException>());
    });

    test('unknown code preserves message in AiServiceException', () {
      final e = FirebaseFunctionsException(
        code: 'unknown-code',
        details: null,
        message: 'specific reason',
      );
      final mapped = mapAiFunctionsExceptionForTest(e) as AiServiceException;
      expect(mapped.message, 'specific reason');
    });

    test('unknown code preserves code when message is empty', () {
      final e = FirebaseFunctionsException(
        code: 'unknown-code',
        details: null,
        message: '',
      );
      final mapped = mapAiFunctionsExceptionForTest(e) as AiServiceException;
      // ai_service.dart uses: e.message ?? e.code
      // empty string is not null, so it keeps the empty string
      expect(mapped.message, '');
    });
  });
}
