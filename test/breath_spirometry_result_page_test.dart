import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
import 'package:no_smoke/pages/breath_spirometry_result_page.dart';

void main() {
  const spirometry = SpirometryEstimate(
    fev1EnergyIntegral: 0.18,
    fvcEnergyIntegral: 0.2,
    fev1FvcRatioPercent: 78,
    peakFlowIndex: 82,
    peakFlowAtMs: 250,
    curve: [
      BreathFlowCurvePoint(
        millisecondsSinceOnset: 0,
        energy: 0.1,
        cumulativeEnergyIntegral: 0,
      ),
      BreathFlowCurvePoint(
        millisecondsSinceOnset: 500,
        energy: 0.3,
        cumulativeEnergyIntegral: 0.1,
      ),
      BreathFlowCurvePoint(
        millisecondsSinceOnset: 1000,
        energy: 0.2,
        cumulativeEnergyIntegral: 0.18,
      ),
    ],
  );

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  testWidgets('renders ratio/peak-flow tiles and disclaimers', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 42,
          riskLevel: 'ORTA',
          spirometry: spirometry,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42 / 100'), findsOneWidget);
    expect(find.textContaining('78%'), findsOneWidget);
    expect(find.textContaining('82/100'), findsOneWidget);
    // "(tahmini)" suffix appears once per metric tile.
    expect(find.text('(tahmini)'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('breath_result_ratio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('breath_result_peak_flow')),
      findsOneWidget,
    );
  });

  testWidgets('continue button navigates to HomePage', (tester) async {
    await tester.pumpWidget(
      wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 20,
          riskLevel: 'DÜŞÜK',
          spirometry: spirometry,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const ValueKey('breath_result_continue'));
    await tester.scrollUntilVisible(continueButton, 200);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(BreathSpirometryResultPage), findsNothing);
  });
}
