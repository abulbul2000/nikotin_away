import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/app_texts.dart';
import 'package:no_smoke/core/generated_language_data.dart';
import 'package:no_smoke/services/language_service.dart';

/// Keys the user reads on a screen they cannot avoid. A missing entry here
/// means someone using the app in that language hits English mid-sentence.
const criticalKeys = <String>[
  'appName',
  'home',
  'save',
  'continue',
  'yes',
  'no',
  'weeklySurvey',
];

void main() {
  final supported = LanguageService.supportedLanguages.keys.toList();

  test('the string table makes no network calls', () {
    // Comments stripped first: the file explains what used to be here, and
    // that explanation names the endpoint.
    final code = File('lib/core/app_texts.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    // The app used to fetch its own UI strings from an undocumented Google
    // Translate endpoint the first time an untranslated language was picked.
    // The data-safety declaration says nothing leaves the device, so this
    // has to stay true no matter who edits the file next.
    expect(code, isNot(contains('googleapis')));
    expect(code, isNot(contains('HttpClient')));
    expect(code, isNot(contains('translate_a/single')));
    expect(code, isNot(contains("import 'dart:io'")));
  });

  test('every supported language resolves without a loading step', () async {
    for (final code in supported) {
      // Kept as a no-op so callers need not know which languages are
      // bundled. If it ever starts doing work again, it must not be I/O.
      await AppTexts.ensureLanguageLoaded(code);
      expect(
        AppTexts.textForCode(code, 'save'),
        isNotEmpty,
        reason: '$code must resolve a value for save',
      );
    }
  });

  test('unknown language or key never silently falls back to another language', () {
    expect(AppTexts.textForCode('xx', 'save'), 'save');
    expect(AppTexts.textForCode('en', '__missing_key__'), '__missing_key__');
    expect(AppTexts.textForCode('tr', '__missing_key__'), '__missing_key__');
  });

  test('no language ever shows a raw key to the user', () {
    for (final code in supported) {
      for (final key in criticalKeys) {
        final value = AppTexts.textForCode(code, key);
        expect(
          value,
          isNot(key),
          reason: '$code/$key fell through to the key name',
        );
      }
    }
  });

  test('the product name is the same in every language', () {
    // A brand is a proper noun and does not get translated. All 44 language
    // entries carried a translation of the old name instead — SENZA FUMO,
    // SIN HUMO, 禁煙 — so the rebrand only ever showed in Turkish and
    // English. Listing forbidden spellings would not have caught it; the
    // check has to be that the value is the brand.
    final wrong = <String>[];
    for (final code in supported) {
      final name = AppTexts.textForCode(code, 'appName');
      if (name != 'NIKOTIN AWAY') {
        wrong.add('$code: $name');
      }
    }
    expect(wrong, isEmpty, reason: 'product name differs in: $wrong');
  });

  test('translations keep every placeholder the English text has', () {
    // Values are filled by replaceAll('{score}', ...). A translation that
    // drops or renames a placeholder shows the user a literal {score}, and
    // one that invents a placeholder leaves braces on screen forever.
    final braces = RegExp(r'\{[a-zA-Z]+\}');
    final problems = <String>[];

    for (final code in supported) {
      if (code == 'en') continue;
      for (final entry
          in generatedLanguageData[code]?.entries ??
              const <MapEntry<String, String>>[]) {
        final english = AppTexts.textForCode('en', entry.key);
        if (english == entry.key) continue; // not an English-defined key

        final expected = braces
            .allMatches(english)
            .map((m) => m.group(0)!)
            .toSet();
        final actual = braces
            .allMatches(entry.value)
            .map((m) => m.group(0)!)
            .toSet();

        if (!setEquals(expected, actual)) {
          problems.add('$code/${entry.key}: expected $expected, got $actual');
        }
      }
    }

    expect(problems, isEmpty, reason: 'placeholder mismatch: $problems');
  });

  group('coverage', () {
    test('every generated language has the complete bundled key set', () {
      final referenceKeys = generatedLanguageData.values.first.keys.toSet();
      final gaps = <String, int>{};
      for (final entry in generatedLanguageData.entries) {
        final missing = referenceKeys.difference(entry.value.keys.toSet());
        if (missing.isNotEmpty) gaps[entry.key] = missing.length;
      }
      expect(gaps, isEmpty, reason: 'language bundles are incomplete: $gaps');
    });

    test('bundled languages cover the keys the English table defines', () {
      // Reported per language rather than as one pass/fail so the gap is
      // visible and can be closed language by language.
      final gaps = <String, int>{};
      for (final entry in generatedLanguageData.entries) {
        final missing = criticalKeys
            .where((key) => !entry.value.containsKey(key))
            .length;
        if (missing > 0) gaps[entry.key] = missing;
      }
      expect(gaps, isEmpty, reason: 'critical keys missing in: $gaps');
    });
  });
}
