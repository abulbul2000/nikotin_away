import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/services/subscription_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('no_smoke_sub_test').path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  late StorageService storage;
  late SubscriptionService service;

  setUp(() async {
    storage = StorageService();
    await storage.clearAllData();
    service = SubscriptionService(storageService: storage);
  });

  test('returns needsSurveyFirst when the initial survey is not done yet', () async {
    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: false,
    );
    expect(decision, AccessDecision.needsSurveyFirst);
  });

  test('allows access while inside the 14-day trial window', () async {
    await storage.startTrialIfNeeded();

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.allowed);
  });

  test('shows the gate once the trial window has elapsed with no subscription', () async {
    await storage.saveSubscriptionState(
      SubscriptionState(
        trialStartedAt: DateTime.now().subtract(const Duration(days: 20)),
        status: SubscriptionStatus.trial,
        updatedAt: DateTime.now(),
      ),
    );

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.showGate);
  });

  test('allows access when subscription is active and verified recently', () async {
    final now = DateTime.now();
    await storage.saveSubscriptionState(
      SubscriptionState(
        trialStartedAt: now.subtract(const Duration(days: 20)),
        status: SubscriptionStatus.active,
        productId: 'monthly_sub',
        lastVerifiedAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      ),
    );

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.allowed);
  });

  test('needs a connection check when the cached active state is stale', () async {
    final now = DateTime.now();
    await storage.saveSubscriptionState(
      SubscriptionState(
        trialStartedAt: now.subtract(const Duration(days: 20)),
        status: SubscriptionStatus.active,
        productId: 'monthly_sub',
        lastVerifiedAt: now.subtract(const Duration(days: 4)),
        updatedAt: now,
      ),
    );

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.needsConnectionCheck);
  });

  test('shows the gate when subscription status is expired', () async {
    final now = DateTime.now();
    await storage.saveSubscriptionState(
      SubscriptionState(
        trialStartedAt: now.subtract(const Duration(days: 20)),
        status: SubscriptionStatus.expired,
        productId: 'monthly_sub',
        lastVerifiedAt: now,
        updatedAt: now,
      ),
    );

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.showGate);
  });
}
