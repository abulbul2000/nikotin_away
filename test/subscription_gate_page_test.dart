import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/subscription_gate_page.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  supportedLocales: const [Locale('tr'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

void main() {
  testWidgets('shows subscription options when the trial has simply ended', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionGatePage()));
    await tester.pump();

    expect(find.text('Deneme Suresi Doldu'), findsOneWidget);
    expect(find.text('Aylik'), findsOneWidget);
    expect(find.text('Yillik'), findsOneWidget);
    expect(find.text('Satin Alimi Geri Yukle'), findsOneWidget);
  });

  testWidgets(
    'shows a connection-only message and retry button when needsConnectionOnly',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SubscriptionGatePage(needsConnectionOnly: true)),
      );
      await tester.pump();

      expect(find.text('Deneme Suresi Doldu'), findsOneWidget);
      expect(
        find.textContaining('internet baglantisi gerekiyor'),
        findsOneWidget,
      );
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Aylik'), findsNothing);
    },
  );

  testWidgets('back gesture cannot dismiss the gate', (tester) async {
    await tester.pumpWidget(_wrap(const SubscriptionGatePage()));
    await tester.pump();

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
