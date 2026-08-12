import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/services/subscription_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  productID: SubscriptionService.monthlyProductId,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: 'server-token',
    source: 'google_play',
  ),
  transactionDate: null,
  status: status,
);

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

  group('handlePurchase', () {
    // purchased/restored also call the verifySubscription Cloud Function,
    // which needs a real Firebase backend this suite doesn't set up — only
    // the statuses that return before that call are covered here.
    test('reports pending without touching storage', () async {
      final outcome = await service.handlePurchase(
        _purchase(PurchaseStatus.pending),
      );
      expect(outcome, PurchaseOutcome.pending);
      expect(await storage.loadSubscriptionState(), isNull);
    });

    test('reports cancelled without touching storage', () async {
      final outcome = await service.handlePurchase(
        _purchase(PurchaseStatus.canceled),
      );
      expect(outcome, PurchaseOutcome.cancelled);
      expect(await storage.loadSubscriptionState(), isNull);
    });

    test('reports failed without touching storage', () async {
      final outcome = await service.handlePurchase(
        _purchase(PurchaseStatus.error),
      );
      expect(outcome, PurchaseOutcome.failed);
      expect(await storage.loadSubscriptionState(), isNull);
    });
  });
}
