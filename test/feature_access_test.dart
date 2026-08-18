import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/subscription_state.dart';
import 'package:no_smoke/services/feature_access.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:no_smoke/services/subscription_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final Directory _dir = Directory.systemTemp.createTempSync(
    'no_smoke_feature_access_test',
  );

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  late StorageService storage;
  late FeatureAccess featureAccess;

  setUp(() async {
    storage = StorageService();
    await storage.clearAllData();
    featureAccess = FeatureAccess(
      subscriptionService: SubscriptionService(
        storageService: storage,
        allowDebugAccess: false,
      ),
    );
  });

  test('every PremiumFeature currently requires a subscription', () {
    for (final feature in PremiumFeature.values) {
      expect(featureAccess.requiresSubscription(feature), isTrue);
    }
  });

  test('release access is false without an active subscription', () async {
    final allowed = await featureAccess.canAccess(PremiumFeature.aiMentor);
    expect(allowed, isFalse);
  });

  test('debug access is true without a subscription', () async {
    final debugAccess = FeatureAccess(
      subscriptionService: SubscriptionService(
        storageService: storage,
        allowDebugAccess: true,
      ),
    );

    final allowed = await debugAccess.canAccess(PremiumFeature.aiMentor);
    expect(allowed, isTrue);
  });

  test(
    'release access is true with an active, recently-verified subscription',
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

      final allowed = await featureAccess.canAccess(
        PremiumFeature.locationIntelligence,
      );

      expect(allowed, isTrue);
    },
  );

  test('only aiMentor requires a paid (non-trial) subscription', () {
    expect(
      featureAccess.requiresPaidSubscription(PremiumFeature.aiMentor),
      isTrue,
    );
    for (final feature in PremiumFeature.values) {
      if (feature == PremiumFeature.aiMentor) continue;
      expect(featureAccess.requiresPaidSubscription(feature), isFalse);
    }
  });

  group('during an active trial', () {
    setUp(() async {
      final now = DateTime.now();
      await storage.saveSubscriptionState(
        SubscriptionState(
          status: SubscriptionStatus.trial,
          trialStartedAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
        ),
      );
    });

    test('non-AI features are unlocked', () async {
      final allowed = await featureAccess.canAccess(
        PremiumFeature.adaptiveTasks,
      );
      expect(allowed, isTrue);
    });

    test('the AI mentor stays gated', () async {
      final allowed = await featureAccess.canAccess(PremiumFeature.aiMentor);
      expect(allowed, isFalse);
    });
  });
}
