import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/pages/smoked_log_consent_page.dart';
import 'package:no_smoke/services/smoked_log_button_service.dart';

/// Records what the flow asked of it, without touching SQLite — a widget test
/// runs in a fake-async zone where a real database read never resolves.
class _FakeButtonService extends SmokedLogButtonService {
  _FakeButtonService({this.alreadyConsented = false}) : super(isAndroid: true);

  final bool alreadyConsented;
  bool enableCalled = false;

  @override
  Future<bool> hasEverConsented() async => alreadyConsented;

  @override
  Future<bool> enable({
    required String notificationTitle,
    required String notificationBody,
    required String actionLabel,
    Map<String, String?> menuLabels = const {},
  }) async {
    enableCalled = true;
    lastMenuLabels = menuLabels;
    return true;
  }

  Map<String, String?> lastMenuLabels = const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel('no_smoke/device_permissions');

  /// Method names the flow invoked on the platform, in order.
  late List<String> permissionCalls;
  late bool hasOverlay;

  setUp(() {
    permissionCalls = [];
    hasOverlay = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          permissionCalls.add(call.method);
          if (call.method == 'hasOverlayPermission') return hasOverlay;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> runOffer(WidgetTester tester, _FakeButtonService service) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => offerSmokedLogButton(context, service: service),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  testWidgets('explains the button before asking for the permission', (
    tester,
  ) async {
    await runOffer(tester, _FakeButtonService());

    // The offer used to check for the overlay permission first and give up
    // silently when it was missing — so on a phone that had never granted
    // it, the one feature that records when the user actually smokes was
    // never even mentioned. "Allow drawing over other apps" means nothing
    // cold; the explanation has to come first.
    expect(find.byType(SmokedLogConsentPage), findsOneWidget);
    expect(
      permissionCalls,
      isNot(contains('requestOverlayPermission')),
      reason: 'permission must not be requested before the explanation',
    );
  });

  testWidgets('accepting then asks for the permission it needs', (
    tester,
  ) async {
    final service = _FakeButtonService();
    await runOffer(tester, service);

    await tester.tap(find.byKey(const ValueKey('smoked_log_consent_accept')));
    await settle(tester);

    // DevicePermissionService is gated on Platform.isAndroid, so off-device
    // the permission trip is a no-op and never reaches the channel — what is
    // observable here is that enabling happens only after acceptance.
    expect(service.enableCalled, isTrue);

    // The choice panel is drawn by native code that has no access to the
    // translation table, so every label it shows has to be handed over at
    // enable time. A missing one renders as a hardcoded Turkish fallback in
    // whatever language the user picked.
    expect(
      service.lastMenuLabels.keys,
      containsAll(<String>[
        'menuTitle',
        'menuSosLabel',
        'menuOpenLabel',
        'menuCancelLabel',
      ]),
    );
    expect(
      service.lastMenuLabels.values.every(
        (label) => label != null && label.isNotEmpty,
      ),
      isTrue,
    );
  });

  testWidgets('declining asks for nothing and turns nothing on', (
    tester,
  ) async {
    final service = _FakeButtonService();
    await runOffer(tester, service);

    await tester.tap(find.byKey(const ValueKey('smoked_log_consent_decline')));
    await settle(tester);

    expect(service.enableCalled, isFalse);
  });

  testWidgets('an already-granted permission is not asked for again', (
    tester,
  ) async {
    hasOverlay = true;
    final service = _FakeButtonService();
    await runOffer(tester, service);

    await tester.tap(find.byKey(const ValueKey('smoked_log_consent_accept')));
    await settle(tester);

    expect(service.enableCalled, isTrue);
  });

  testWidgets('someone who already answered is never asked again', (
    tester,
  ) async {
    final service = _FakeButtonService(alreadyConsented: true);
    await runOffer(tester, service);

    // Both setup and the dashboard call this. Whichever runs second must
    // not re-explain a feature the user has already decided about.
    expect(find.byType(SmokedLogConsentPage), findsNothing);
    expect(service.enableCalled, isFalse);
  });
}
