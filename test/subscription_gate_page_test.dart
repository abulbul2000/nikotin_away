import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:no_smoke/pages/subscription_gate_page.dart';
import 'package:no_smoke/services/subscription_service.dart';

/// Stands in for the real `in_app_purchase`-backed [SubscriptionService] —
/// there's no Play Store to talk to in a test environment, and without this
/// double [SubscriptionGatePage]'s initState call to loadProducts() hangs
/// forever waiting on a platform channel nothing answers.
class _FakeSubscriptionService extends SubscriptionService {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController.broadcast();

  @override
  Future<List<ProductDetails>> loadProducts() async => const [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> buy(ProductDetails product) async => true;

  @override
  Future<bool> restore() async => true;
}

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
  testWidgets('shows a store-unavailable message when no products load', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SubscriptionGatePage(subscriptionService: _FakeSubscriptionService()),
      ),
    );
    await tester.pump();

    expect(find.text('Deneme Suresi Doldu'), findsOneWidget);
    expect(find.text('Satin Alimi Geri Yukle'), findsOneWidget);
    // No products came back (empty store response), so the gate falls back
    // to its "store unavailable" message instead of listing plans.
    expect(
      find.text(
        'Magaza su anda ulasilamaz durumda. Lutfen daha sonra tekrar dene.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aylik'), findsNothing);
    expect(find.text('Yillik'), findsNothing);
  });

  testWidgets(
    'shows a connection-only message and retry button when needsConnectionOnly',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SubscriptionGatePage(
            needsConnectionOnly: true,
            subscriptionService: _FakeSubscriptionService(),
          ),
        ),
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
    await tester.pumpWidget(
      _wrap(
        SubscriptionGatePage(subscriptionService: _FakeSubscriptionService()),
      ),
    );
    await tester.pump();

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
