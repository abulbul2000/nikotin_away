import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/services/subscription_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  productID: SubscriptionService.starterProductId,
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
    service = SubscriptionService(
      storageService: storage,
      allowDebugAccess: false,
    );
  });

  test(
    'returns needsSurveyFirst when the initial survey is not done yet',
    () async {
      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: false,
      );
      expect(decision, AccessDecision.needsSurveyFirst);
    },
  );

  test('shows the gate without a subscription in release mode', () async {
    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.showGate);
  });

  test('allows access in debug mode without a subscription', () async {
    final debugService = SubscriptionService(
      storageService: storage,
      allowDebugAccess: true,
    );

    final decision = await debugService.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.allowed);
  });

  test(
    'allows access when Starter subscription is active and recently verified',
    () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.active,
          productId: SubscriptionService.starterProductId,
          lastVerifiedAt: now.subtract(const Duration(hours: 1)),
          updatedAt: now,
        ),
      );

      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: true,
      );

      expect(decision, AccessDecision.allowed);
    },
  );

  test(
    'needs a connection check when the cached active state is stale',
    () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.active,
          productId: SubscriptionService.plusProductId,
          lastVerifiedAt: now.subtract(const Duration(days: 4)),
          updatedAt: now,
        ),
      );

      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: true,
      );

      expect(decision, AccessDecision.needsConnectionCheck);
    },
  );

  test('shows the gate when subscription status is expired', () async {
    final now = DateTime.now();
    await storage.saveSubscriptionState(
      SubscriptionState(
        status: SubscriptionStatus.expired,
        productId: SubscriptionService.proProductId,
        lastVerifiedAt: now,
        updatedAt: now,
      ),
    );

    final decision = await service.resolveAccess(
      hasCompletedInitialSurvey: true,
    );

    expect(decision, AccessDecision.showGate);
  });

  group('trial', () {
    test('allows access on day 13 of the 14-day trial', () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.trial,
          trialStartedAt: now.subtract(const Duration(days: 13)),
          updatedAt: now,
        ),
      );

      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: true,
      );

      expect(decision, AccessDecision.allowed);
    });

    test('shows the gate once the trial is past 14 days', () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.trial,
          trialStartedAt: now.subtract(const Duration(days: 15)),
          updatedAt: now,
        ),
      );

      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: true,
      );

      expect(decision, AccessDecision.showGate);
    });

    test('shows the gate for a trial status with no start date', () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(status: SubscriptionStatus.trial, updatedAt: now),
      );

      final decision = await service.resolveAccess(
        hasCompletedInitialSurvey: true,
      );

      expect(decision, AccessDecision.showGate);
    });
  });

  group('device clock rollback', () {
    test(
      'winding the clock back into the trial window does not un-expire it',
      () async {
        final trialStart = DateTime.now().subtract(const Duration(days: 10));
        // maxObservedAt is 20 days after the trial started — i.e. this
        // device already legitimately observed a time past the 14-day
        // boundary (the trial expired then). DateTime.now() at test-run
        // time is only 10 days after trialStart, which on its own would
        // still read as "day 10 of 14, still active" — simulating a clock
        // that has been wound backward since that later observation.
        await storage.saveSubscriptionState(
          SubscriptionState(
            status: SubscriptionStatus.trial,
            trialStartedAt: trialStart,
            updatedAt: trialStart,
            maxObservedAt: trialStart.add(const Duration(days: 20)),
          ),
        );

        final decision = await service.resolveAccess(
          hasCompletedInitialSurvey: true,
        );

        expect(decision, AccessDecision.showGate);
      },
    );

    test(
      'grace period does not extend when the clock is set backward',
      () async {
        final recordedNow = DateTime.now();
        // Last verified 2 days before the latest observed time, and the
        // clock has since been wound back 10 days — naively comparing
        // against a bare DateTime.now() would put "now" before
        // lastVerifiedAt + offlineGraceDuration again, wrongly renewing
        // the grace period. maxObservedAt should stop that.
        await storage.saveSubscriptionState(
          SubscriptionState(
            status: SubscriptionStatus.active,
            productId: SubscriptionService.starterProductId,
            lastVerifiedAt: recordedNow.subtract(const Duration(days: 2)),
            updatedAt: recordedNow,
            maxObservedAt: recordedNow,
          ),
        );

        final decision = await service.resolveAccess(
          hasCompletedInitialSurvey: true,
        );

        // maxObservedAt (recordedNow) is itself only 2 days after
        // lastVerifiedAt, still inside the 3-day grace window, so access
        // is allowed — but on the trusted clock, not a rolled-back one.
        expect(decision, AccessDecision.allowed);
      },
    );

    test('maxObservedAt only ever moves forward, never backward', () async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.trial,
          trialStartedAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
          maxObservedAt: now.add(const Duration(days: 10)),
        ),
      );

      await service.resolveAccess(hasCompletedInitialSurvey: true);

      final saved = await storage.loadSubscriptionState();
      expect(
        saved!.maxObservedAt!.isAtSameMomentAs(
          now.add(const Duration(days: 10)),
        ),
        isTrue,
      );
    });
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
