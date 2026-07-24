import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/protocol_violation_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_protocol_violation_test')
        .path;
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
    final storage = StorageService();
    await storage.clearAllData();
  });

  test('logSuspiciousBehavior records type=suspicious_behavior, severity=high', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logSuspiciousBehavior(taskTitle: 'Bir bardak su ic');

    final violations = await storage.loadProtocolViolations();
    expect(violations, hasLength(1));
    expect(violations.first.type, 'suspicious_behavior');
    expect(violations.first.severity, 'high');
    expect(violations.first.taskTitle, 'Bir bardak su ic');
  });

  test('logWillpowerWeakness records type=willpower_weakness, severity=medium', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logWillpowerWeakness(taskTitle: 'Gorev A');

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'willpower_weakness');
    expect(violations.first.severity, 'medium');
  });

  test('logDeferredStart records type=deferred_start, severity=medium', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logDeferredStart(taskTitle: 'Gorev B');

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'deferred_start');
    expect(violations.first.severity, 'medium');
  });

  test('logFollowUpDeferred records type=followup_deferred, severity=low, custom details', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logFollowUpDeferred(
      taskTitle: 'Gorev C',
      details: 'custom detail',
    );

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'followup_deferred');
    expect(violations.first.severity, 'low');
    expect(violations.first.details, 'custom detail');
  });

  test('logDurationBarrierFailure records type=duration_barrier_failure, severity=medium', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logDurationBarrierFailure(command: '30 dakika sigarasiz kal');

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'duration_barrier_failure');
    expect(violations.first.severity, 'medium');
  });

  test('logMandatoryGateShown records type=mandatory_gate, severity=medium', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logMandatoryGateShown(taskTitle: 'Gorev D');

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'mandatory_gate');
    expect(violations.first.severity, 'medium');
  });

  test('logFollowUpFailed records type=followup_failed, severity=medium', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logFollowUpFailed(taskTitle: 'Gorev E');

    final violations = await storage.loadProtocolViolations();
    expect(violations.first.type, 'followup_failed');
    expect(violations.first.severity, 'medium');
  });

  test('logSuspiciousBehavior also creates a supportive reframed mentor message', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logSuspiciousBehavior(taskTitle: 'Gorev F');

    final latest = await storage.loadLatestMentorMessage();
    expect(latest, isNotNull);
    expect(latest!.type, 'reframed_violation');
    expect(latest.tone, 'supportive');
  });

  test('logMandatoryGateShown does NOT create a reframed mentor message (purely informational)', () async {
    final storage = StorageService();
    final service = ProtocolViolationService(storageService: storage);

    await service.logMandatoryGateShown(taskTitle: 'Gorev G');

    final latest = await storage.loadLatestMentorMessage();
    expect(latest, isNull);
  });
}
