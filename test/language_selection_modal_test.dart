import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/language_selection_page.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

void main() {
  testWidgets(
    'the clear-search button empties the visible text field, not just the internal filter',
    (tester) async {
      // Regression coverage: the search TextField had no controller, so the
      // clear button (and the "other languages"/"back" buttons, which also
      // reset the search query) only ever reset the internal _searchQuery
      // state used to filter the list -- the TextField's own visible text
      // was never cleared, since nothing but a controller can do that. A
      // user tapping "clear" saw the language list reset to unfiltered
      // while their typed search term stayed visibly sitting in the box.
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: LanguageSelectionModal(
                selectedCode: 'en',
                onLanguageSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'germ');
      await tester.pumpAndSettle();
      expect(find.text('germ'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('germ'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'switching to "other languages" also clears any typed search text',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: LanguageSelectionModal(
                selectedCode: 'en',
                onLanguageSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    },
  );
}
