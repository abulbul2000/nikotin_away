import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/app_texts.dart';

/// The five conditions the app asks about, and the key prefix each one's
/// tips live under (mirrors NotificationService._healthTipPrefixByCondition,
/// which is private).
const tipPrefixes = <String, String>{
  'Hipertansiyon': 'healthTipHypertension',
  'Astim': 'healthTipAsthma',
  'Diyabet': 'healthTipDiabetes',
  'KOAH': 'healthTipCopd',
  'Kalp Hastaligi': 'healthTipHeartDisease',
};

/// Must match NotificationService._healthTipsPerCondition. A pool declared
/// larger than the texts that exist doesn't crash — the tip is dropped from
/// the reminder — so nothing but a test notices.
const tipsPerCondition = 30;

void main() {
  test('every declared tip exists in Turkish and English', () {
    final missing = <String>[];
    for (final prefix in tipPrefixes.values) {
      for (var index = 1; index <= tipsPerCondition; index++) {
        final key = '$prefix$index';
        for (final code in ['tr', 'en']) {
          final value = AppTexts.textForCode(code, key);
          if (value == key || value.trim().isEmpty) {
            missing.add('$code/$key');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: 'missing tip texts: $missing');
  });

  test('the pool is 150 tips — five conditions of thirty', () {
    expect(tipPrefixes, hasLength(5));
    expect(tipPrefixes.length * tipsPerCondition, 150);
  });

  test('no tip is duplicated within a condition', () {
    for (final prefix in tipPrefixes.values) {
      for (final code in ['tr', 'en']) {
        final seen = <String, int>{};
        for (var index = 1; index <= tipsPerCondition; index++) {
          final text = AppTexts.textForCode(code, '$prefix$index');
          expect(
            seen.containsKey(text),
            isFalse,
            reason: '$code/$prefix$index repeats $prefix${seen[text]}',
          );
          seen[text] = index;
        }
      }
    }
  });

  test('tips carry no dosing, diagnosis or treatment instruction', () {
    // The product rule is that health text stays at general-lifestyle level.
    // These are the shapes that would mean it had drifted into advice only a
    // clinician should give.
    //
    // Units are matched next to a number rather than as bare words: `\b`
    // treats Turkish letters like ı and ş as non-word characters, so a plain
    // `\bml\b` fires inside "Astımlı". A dose is a number and a unit anyway.
    final forbidden = RegExp(
      r'\d\s*(mg|ml|mcg|iu)|'
      r'(doz|dozu|dozunu|dosage|milligram)|'
      r'ila(c|ç)(ını|ini) (kes|bırak|artır|azalt)|'
      r'(stop|start) taking|(increase|reduce) your dose',
      caseSensitive: false,
    );

    final offenders = <String>[];
    for (final prefix in tipPrefixes.values) {
      for (var index = 1; index <= tipsPerCondition; index++) {
        for (final code in ['tr', 'en']) {
          final text = AppTexts.textForCode(code, '$prefix$index');
          if (forbidden.hasMatch(text)) {
            offenders.add('$code/$prefix$index: $text');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: 'clinical instruction in: $offenders');
  });

  test('the disclaimer that rides under every tip exists', () {
    for (final code in ['tr', 'en']) {
      final disclaimer = AppTexts.textForCode(
        code,
        'medicationAdviceDisclaimer',
      );
      expect(disclaimer, isNot('medicationAdviceDisclaimer'));
      expect(disclaimer.trim(), isNotEmpty);
    }
  });
}
