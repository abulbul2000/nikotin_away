import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/notification_budget.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/widgets/notification_kinds_card.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_notif_kinds').path;
  }
}

/// Answers in-memory rather than through sqflite. Widget tests run in
/// flutter_test's fake-async pump loop, which never lets sqflite's real
/// (native FFI) I/O resolve — a widget waiting on the real StorageService
/// stays on its loading state forever.
class _FakeStorageService extends StorageService {
  final Map<String, bool> _state = {};

  @override
  Future<bool> isNotificationKindEnabled(String kindName) async {
    return _state[kindName] ?? true;
  }

  @override
  Future<void> setNotificationKindEnabled(
    String kindName,
    bool enabled,
  ) async {
    _state[kindName] = enabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    await StorageService().clearAllData();
  });

  test('every offered kind defaults to on', () async {
    final storage = StorageService();
    for (final kind in NotificationKind.values) {
      if (const NotificationBudget().classOf(kind) !=
          NotificationClass.offered) {
        continue;
      }
      // A user who never opens this screen must see the same behaviour as
      // before it existed.
      expect(await storage.isNotificationKindEnabled(kind.name), isTrue);
    }
  });

  test('turning a kind off is read immediately, not just on restart', () async {
    final storage = StorageService();
    await storage.setNotificationKindEnabled(
      NotificationKind.healthTip.name,
      false,
    );

    expect(
      await storage.isNotificationKindEnabled(NotificationKind.healthTip.name),
      isFalse,
    );
    // Unrelated kinds are untouched by one toggle.
    expect(
      await storage.isNotificationKindEnabled(
        NotificationKind.breathTest.name,
      ),
      isTrue,
    );
  });

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );

  testWidgets('the card shows a switch for every offered kind, none for owed', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(NotificationKindsCard(storageService: _FakeStorageService())),
    );
    await tester.pumpAndSettle();

    const budget = NotificationBudget();
    for (final kind in NotificationKind.values) {
      final finder = find.byKey(ValueKey('notification_kind_${kind.name}'));
      if (budget.classOf(kind) == NotificationClass.offered) {
        expect(
          finder,
          findsOneWidget,
          reason: '$kind is offered and must have a switch',
        );
      } else {
        expect(
          finder,
          findsNothing,
          reason: '$kind is owed and must not be a preference',
        );
      }
    }
  });

  testWidgets('tapping a switch persists the change', (tester) async {
    final fake = _FakeStorageService();
    await tester.pumpWidget(
      wrap(NotificationKindsCard(storageService: fake)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('notification_kind_sedentary')),
    );
    await tester.pump();

    expect(
      await fake.isNotificationKindEnabled(NotificationKind.sedentary.name),
      isFalse,
    );
  });
}
