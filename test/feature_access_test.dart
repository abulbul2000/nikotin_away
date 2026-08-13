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
      subscriptionService: SubscriptionService(storageService: storage),
    );
  });

  test('every PremiumFeature currently requires a subscription', () {
    for (final feature in PremiumFeature.values) {
      expect(featureAccess.requiresSubscription(feature), isTrue);
    }
  });

  test('canAccess is true while inside the trial window', () async {
    await storage.startTrialIfNeeded();

    final allowed = await featureAccess.canAccess(PremiumFeature.aiMentor);

    expect(allowed, isTrue);
  });

  test(
    'canAccess is false once the trial has elapsed with no subscription',
    () async {
      await storage.saveSubscriptionState(
        SubscriptionState(
          trialStartedAt: DateTime.now().subtract(const Duration(days: 20)),
          status: SubscriptionStatus.trial,
          updatedAt: DateTime.now(),
        ),
      );

      final allowed = await featureAccess.canAccess(
        PremiumFeature.breathCoughTests,
      );

      expect(allowed, isFalse);
    },
  );

  test(
    'canAccess is true with an active, recently-verified subscription',
    () async {
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

      final allowed = await featureAccess.canAccess(
        PremiumFeature.locationIntelligence,
      );

      expect(allowed, isTrue);
    },
  );
}
