import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_acoustic_engine.dart';
import 'package:no_smoke/engines/wheeze_detection_engine.dart';
import 'package:no_smoke/pages/breath_spirometry_result_page.dart';

const _fakeSpirometry = SpirometryEstimate(
  fev1EnergyIntegral: 10,
  fvcEnergyIntegral: 14,
  fev1FvcRatioPercent: 71,
  peakFlowIndex: 60,
  peakFlowAtMs: 300,
  curve: [],
);

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('no wheeze card when wheeze is null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          spirometry: _fakeSpirometry,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('breath_result_wheeze_card')),
      findsNothing,
    );
  });

  testWidgets('no wheeze card when wheeze was not detected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          spirometry: _fakeSpirometry,
          wheeze: WheezeAnalysis.none,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('breath_result_wheeze_card')),
      findsNothing,
    );
  });

  testWidgets('shows the wheeze card with severity and advice when detected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          spirometry: _fakeSpirometry,
          wheeze: WheezeAnalysis(
            wheezeDetected: true,
            severityLevel: 'moderate',
            severityScore: 50,
            wheezeBandEnergyRatio: 0.5,
            dominantFrequencyHz: 400,
            wheezeDurationMs: 1500,
          ),
          wheezeAdvisoryTier: 'moderate',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('breath_result_wheeze_card')),
      findsOneWidget,
    );
    expect(find.text('Orta duzeyde hiriltili nefes tespit edildi.'), findsOneWidget);
  });
}
