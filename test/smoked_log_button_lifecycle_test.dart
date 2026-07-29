import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/smoked_log_button_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_quicklog').path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('no_smoke/watchdog');

  /// Every setSmokedLogButtonEnabled call the service made.
  late List<Map<Object?, Object?>> nativeCalls;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setSmokedLogButtonEnabled') {
            nativeCalls.add(call.arguments as Map<Object?, Object?>);
            return true;
          }
          if (call.method == 'consumeSmokedLogEvents') {
            return <dynamic>[];
          }
          return null;
        });
    await StorageService().clearAllData();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> enable(SmokedLogButtonService service) async {
    await service.enable(
      notificationTitle: 'title',
      notificationBody: 'body',
      actionLabel: 'action',
    );
  }

  Future<void> restore(SmokedLogButtonService service) async {
    await service.restoreIfEnabled(
      notificationTitle: 'title',
      notificationBody: 'body',
      actionLabel: 'action',
    );
  }

  test('restoring re-arms the overlay when the button was left on', () async {
    final service = SmokedLogButtonService(isAndroid: true);
    await enable(service);
    nativeCalls.clear();

    // Android does not restart the overlay service after a reboot, so the
    // app has to ask for it again on the next launch. Without this the
    // button vanished on the first restart while the settings switch still
    // read "on" — which looked like the feature had simply broken.
    await restore(service);

    expect(nativeCalls, hasLength(1));
    expect(nativeCalls.single['enabled'], isTrue);
  });

  test('restoring does nothing when the user turned the button off', () async {
    final service = SmokedLogButtonService(isAndroid: true);
    await enable(service);
    await service.disable();
    nativeCalls.clear();

    await restore(service);

    expect(nativeCalls, isEmpty);
  });

  test('restoring does nothing on a fresh install', () async {
    await restore(SmokedLogButtonService(isAndroid: true));

    expect(nativeCalls, isEmpty);
  });

  test('the disclosure is remembered separately from the switch', () async {
    final service = SmokedLogButtonService(isAndroid: true);
    expect(await service.hasEverConsented(), isFalse);

    await enable(service);
    expect(await service.hasEverConsented(), isTrue);

    // Turning it off must not make the app re-explain itself next time —
    // and must not make setup offer it again as though it were new.
    await service.disable();
    expect(await service.hasEverConsented(), isTrue);
    expect(await service.isEnabled(), isFalse);
  });

  test('a refused native start leaves the preference off', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);

    final service = SmokedLogButtonService(isAndroid: true);
    await enable(service);

    // enable() reports failure rather than storing a preference for a button
    // that cannot be drawn; otherwise the switch sits on while the screen
    // stays empty.
    expect(await service.isEnabled(), isFalse);
    expect(await service.hasEverConsented(), isFalse);
  });
}
