import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/breath_spirometry_result_page.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final Directory _dir = Directory.systemTemp.createTempSync(
    'no_smoke_breath_result_test',
  );

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().clearAllData();
  });

  testWidgets('no wheeze card when wheeze was not detected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          breathScore: 62,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('breath_result_wheeze_card')),
      findsNothing,
    );
  });

  testWidgets(
    'shows a neutral note (not a severity level) when wheeze was detected',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BreathSpirometryResultPage(
            name: 'Ada',
            riskScore: 40,
            riskLevel: 'ORTA',
            breathScore: 62,
            wheezeDetected: true,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('breath_result_wheeze_card')),
        findsOneWidget,
      );
      expect(
        find.text('Bu testte olagandisi bir ses paterni duyuldu.'),
        findsOneWidget,
      );
      // No clinical severity wording should survive on this screen.
      expect(find.textContaining('duzeyde'), findsNothing);
    },
  );

  testWidgets('shows the breath score, not FEV1/FVC or peak flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const BreathSpirometryResultPage(
          name: 'Ada',
          riskScore: 40,
          riskLevel: 'ORTA',
          breathScore: 62,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('62 / 100'), findsOneWidget);
    expect(find.textContaining('FEV1'), findsNothing);
    expect(find.textContaining('Spirometri'), findsNothing);
  });
}
