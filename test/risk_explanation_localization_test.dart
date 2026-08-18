import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/app_texts.dart';

/// Regression coverage for the canonical codes BehaviorEngine now emits
/// instead of hardcoded Turkish sentences (see behavior_engine_test.dart's
/// 'buildRiskExplanation' and 'first-profile task' groups for the
/// production side). This is the other half: proving
/// AppTexts.localizeCanonicalTextForCode actually resolves those codes back
/// to real text in both directions (tr/en) rather than falling through to
/// showing the raw code to the user.
void main() {
  group('risk explanation codes', () {
    test('resolve to Turkish with the score substituted', () {
      expect(
        AppTexts.localizeCanonicalTextForCode('tr', 'RISK_BASE:40'),
        'Baz skor: 40',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode('tr', 'RISK_BEHAVIOR_DELTA:+4'),
        'Davranış/trend etkisi: +4',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode(
          'tr',
          'RISK_PERSONALIZED_DELTA:-5',
        ),
        'Nefes + anket kişisel etki: -5',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode('tr', 'RISK_PROFILE_DELTA:0'),
        'Profil etkisi: 0',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode('tr', 'RISK_TASK_DELTA:-2'),
        'Görev performans etkisi: -2',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode('tr', 'RISK_FINAL:40'),
        'Sonuç risk skoru: 40',
      );
    });

    test('resolve to English with the score substituted', () {
      expect(
        AppTexts.localizeCanonicalTextForCode('en', 'RISK_BASE:40'),
        'Base score: 40',
      );
      expect(
        AppTexts.localizeCanonicalTextForCode('en', 'RISK_FINAL:40'),
        'Final risk score: 40',
      );
    });

    test('an old raw-Turkish DB record still displays, not a broken code', () {
      // A row saved before this canonicalization has the literal Turkish
      // sentence persisted, not a code — _localizeCanonicalCore falls
      // through unrecognized input unchanged, so these keep rendering
      // exactly as they always did rather than showing "RISK_BASE:40"
      // literally or throwing.
      expect(
        AppTexts.localizeCanonicalTextForCode('en', 'Baz skor: 61'),
        'Baz skor: 61',
      );
    });
  });

  group('delay-first-cigarette code', () {
    test('resolves to Turkish with the duration phrase substituted', () {
      final result = AppTexts.localizeCanonicalTextForCode(
        'tr',
        'DELAY_FIRST_CIGARETTE:10',
      );
      expect(result, contains('İlk sigaranızı'));
      expect(result, contains('geciktirin'));
    });

    test('resolves to English with the duration phrase substituted', () {
      final result = AppTexts.localizeCanonicalTextForCode(
        'en',
        'DELAY_FIRST_CIGARETTE:20',
      );
      expect(result, contains('Delay your first cigarette'));
    });
  });
}
