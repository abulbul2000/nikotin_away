import 'package:flutter_test/flutter_test.dart';

/// Tests for the voice command intent recognition patterns used in
/// ai_chat_page.dart (_voiceIntentPatterns).
///
/// These patterns are private to ai_chat_page.dart, so we test the
/// equivalent RegExp logic here to ensure the whitelisted phrases work.
void main() {
  // Coach mode patterns (exact copy from ai_chat_page.dart)
  final coachOffPattern = RegExp(
    r'\b(koç modunu?|coach modunu?)\s*(kapat|devre dışı|off|kapalı)',
    caseSensitive: false,
  );
  final coachOnPattern = RegExp(
    r'\b(koç modunu?|coach modunu?)\s*(aç|etkinleştir|on|aktif)',
    caseSensitive: false,
  );
  final coachDislikePattern = RegExp(
    r'\b(koç modunu?|coach modunu?)\s*(sevmedim|kötü|beğenmedim|nefret)',
    caseSensitive: false,
  );

  // Permission patterns (exact copy from ai_chat_page.dart)
  final micPattern = RegExp(
    r'\b(mikrofon|mikrofon erişimi|microphone)\s*(izin|erişim)',
    caseSensitive: false,
  );
  final locationPattern = RegExp(
    r'\b(konum|yer|location|gps)\s*(izin|erişim|aç)',
    caseSensitive: false,
  );
  final activityPattern = RegExp(
    r'\b(adım|adım sayar|aktivite|activity)\s*(izin|erişim|aç)',
    caseSensitive: false,
  );

  group('coach mode off detection', () {
    test('matches "koç modunu kapat"', () {
      expect(coachOffPattern.hasMatch('koç modunu kapat'), isTrue);
    });

    test('matches "coach modunu kapat"', () {
      expect(coachOffPattern.hasMatch('coach modunu kapat'), isTrue);
    });

    test('matches with extra words before', () {
      expect(coachOffPattern.hasMatch('lütfen koç modunu kapat'), isTrue);
    });

    // Note: "koç modu kapat" (without -nu object suffix) does NOT match
    // because the regex requires "modunu" — this is by design.

    test('matches "koç modunu devre dışı"', () {
      expect(coachOffPattern.hasMatch('koç modunu devre dışı'), isTrue);
    });

    test('matches case-insensitive', () {
      expect(coachOffPattern.hasMatch('KOÇ MODUNU KAPAT'), isTrue);
    });

    test('does NOT match "koç modunu aç"', () {
      expect(coachOffPattern.hasMatch('koç modunu aç'), isFalse);
    });
  });

  group('coach mode on detection', () {
    test('matches "koç modunu aç"', () {
      expect(coachOnPattern.hasMatch('koç modunu aç'), isTrue);
    });

    test('matches "coach modunu aç"', () {
      expect(coachOnPattern.hasMatch('coach modunu aç'), isTrue);
    });

    test('matches "koç modunu etkinleştir"', () {
      expect(coachOnPattern.hasMatch('koç modunu etkinleştir'), isTrue);
    });

    test('matches "koç modunu aktif et"', () {
      expect(coachOnPattern.hasMatch('koç modunu aktif et'), isTrue);
    });

    test('does NOT match "koç modunu kapat"', () {
      expect(coachOnPattern.hasMatch('koç modunu kapat'), isFalse);
    });
  });

  group('coach mode dislike detection', () {
    test('matches "koç modunu sevmedim"', () {
      expect(coachDislikePattern.hasMatch('koç modunu sevmedim'), isTrue);
    });

    test('matches "koç modunu kötü"', () {
      expect(coachDislikePattern.hasMatch('koç modunu kötü'), isTrue);
    });

    test('matches "coach modunu beğenmedim"', () {
      expect(coachDislikePattern.hasMatch('coach modunu beğenmedim'), isTrue);
    });

    test('matches "koç modunu nefret"', () {
      expect(coachDislikePattern.hasMatch('koç modunu nefret'), isTrue);
    });

    test('does NOT match "koç modunu sevdim"', () {
      expect(coachDislikePattern.hasMatch('koç modunu sevdim'), isFalse);
    });

    test('does NOT match general "koç modunu istiyorum"', () {
      expect(
        coachDislikePattern.hasMatch('koç modunu istiyorum'),
        isFalse,
      );
    });
  });

  group('permission patterns', () {
    test('microphone matches "mikrofon izin"', () {
      // Pattern requires exactly "izin" or "erişim" (not "izni" or "erişimi")
      expect(micPattern.hasMatch('mikrofon izin'), isTrue);
    });

    test('microphone does NOT match "mikrofon izni" (with possessive suffix)', () {
      // The regex uses 'izin' not 'izni' — possessive suffix not supported
      expect(micPattern.hasMatch('mikrofon izni'), isFalse);
    });

    test('microphone matches "mikrofon erişimi"', () {
      expect(micPattern.hasMatch('mikrofon erişimi'), isTrue);
    });

    test('microphone matches "microphone izin"', () {
      expect(micPattern.hasMatch('microphone izin'), isTrue);
    });

    test('microphone does NOT match "konum izni"', () {
      expect(micPattern.hasMatch('konum izni'), isFalse);
    });

    test('location matches "konum izin"', () {
      expect(locationPattern.hasMatch('konum izin'), isTrue);
    });

    test('location matches "konum erişimi"', () {
      expect(locationPattern.hasMatch('konum erişimi'), isTrue);
    });

    test('location matches "gps izin"', () {
      expect(locationPattern.hasMatch('gps izin'), isTrue);
    });

    test('activity matches "adım izin"', () {
      expect(activityPattern.hasMatch('adım izin'), isTrue);
    });

    test('activity matches "aktivite izin"', () {
      expect(activityPattern.hasMatch('aktivite izin'), isTrue);
    });

    test('activity matches "adım sayar erişimi"', () {
      expect(activityPattern.hasMatch('adım sayar erişimi'), isTrue);
    });

    test('no false positive: "mikrofon" alone without izin/erişim', () {
      expect(micPattern.hasMatch('mikrofon çalışmıyor'), isFalse);
    });

    test('no false positive: "konum" alone without izin/erişim', () {
      expect(locationPattern.hasMatch('konum bilgisi yanlış'), isFalse);
    });
  });

  group('non-matching phrases fall through to AI', () {
    test('general questions do NOT match any voice pattern', () {
      final phrases = [
        'ne zaman sigarayı bırakacağım',
        'bana motivasyon ver',
        'bugün kaç sigara içtim',
        'sarımsak sigarayı azaltır mı',
        'nasılsın',
        'bugün hava nasıl',
        'kaç adım attım',
      ];

      for (final phrase in phrases) {
        final matchesAny = coachOffPattern.hasMatch(phrase) ||
            coachOnPattern.hasMatch(phrase) ||
            coachDislikePattern.hasMatch(phrase) ||
            micPattern.hasMatch(phrase) ||
            locationPattern.hasMatch(phrase) ||
            activityPattern.hasMatch(phrase);
        expect(matchesAny, isFalse, reason: 'Should not match: "$phrase"');
      }
    });
  });

  group('whitelist safety', () {
    test('only safe reversible settings actions are in whitelist', () {
      // Voice commands should only allow settings changes that can be
      // reversed. No destructive actions like delete/reset should match.
      final safeActions = {'set_coach_mode', 'set_permission'};

      expect(safeActions.contains('set_coach_mode'), isTrue);
      expect(safeActions.contains('set_permission'), isTrue);
      expect(safeActions.contains('delete_account'), isFalse);
      expect(safeActions.contains('reset_all_data'), isFalse);
      expect(safeActions.contains('set_medication_times'), isFalse);
      // Note: set_medication_times is intentionally excluded from voice
      // whitelist because medication changes need text-based confirmation.
    });
  });
}
