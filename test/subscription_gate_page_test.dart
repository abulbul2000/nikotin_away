import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:no_smoke/core/app_texts.dart';
import 'package:no_smoke/pages/subscription_gate_page.dart';
import 'package:no_smoke/services/subscription_service.dart';

/// Resolves the Turkish copy from the string table instead of repeating it as
/// a literal. These assertions used to hardcode the text, so a spelling fix in
/// `app_texts.dart` broke the test even though the page was behaving correctly.
String _tr(String key) => AppTexts.textForCode('tr', key);

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

    expect(find.text(_tr('subscriptionGateTitle')), findsOneWidget);
    expect(find.text(_tr('subscriptionRestoreButton')), findsOneWidget);
    // No products came back (empty store response), so the gate falls back
    // to its "store unavailable" message instead of listing plans.
    expect(find.text(_tr('subscriptionStoreUnavailable')), findsOneWidget);
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

      expect(find.text(_tr('subscriptionGateTitle')), findsOneWidget);
      expect(
        find.textContaining('internet bağlantısı gerekiyor'),
        findsOneWidget,
      );
      expect(find.text(_tr('subscriptionRetryButton')), findsOneWidget);
      expect(find.text('Aylik'), findsNothing);
    },
  );

  testWidgets('shows a "continue for free" option instead of a hard lock', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SubscriptionGatePage(subscriptionService: _FakeSubscriptionService()),
      ),
    );
    await tester.pump();

    expect(find.byType(PopScope), findsNothing);
    expect(
      find.byKey(const ValueKey('subscription_gate_continue_free')),
      findsOneWidget,
    );
    expect(find.text(_tr('subscriptionContinueFreeButton')), findsOneWidget);
  });
}
