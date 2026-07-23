import 'health_connect_service.dart';
import 'storage_service.dart';

/// Orchestrates the opt-in Wearable Intelligence feature (Phase 9 spike):
/// turning it on requests Health Connect read permissions interactively;
/// turning it off just clears the flag. There is no background
/// sync/schedule to arm or cancel here (unlike Sleep/Location/Step
/// Intelligence) — Health Connect reads happen on demand, on the settings
/// card, not via a native probe.
class WearableIntelligenceService {
  final StorageService _storageService;
  final HealthConnectService _healthConnectService;

  static const String consentTextVersion = 'v1';

  WearableIntelligenceService({
    StorageService? storageService,
    HealthConnectService? healthConnectService,
  }) : _storageService = storageService ?? StorageService(),
       _healthConnectService = healthConnectService ?? HealthConnectService();

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting(
          'wearable_intelligence_enabled',
        )) ==
        '1';
  }

  /// Returns true only if the user both wants the feature on AND actually
  /// granted the Health Connect permissions — callers use this to decide
  /// whether to show an error state.
  Future<bool> enable() async {
    final available = await _healthConnectService.isAvailable();
    if (!available) {
      return false;
    }
    final granted = await _healthConnectService.requestPermissions();
    await _storageService.recordConsentDecision(
      featureKey: 'wearable_intelligence',
      granted: granted,
      consentTextVersion: consentTextVersion,
    );
    if (!granted) {
      return false;
    }
    await _storageService.saveSetting('wearable_intelligence_enabled', '1');
    return true;
  }

  Future<void> disable() async {
    await _storageService.saveSetting('wearable_intelligence_enabled', '0');
    await _storageService.recordConsentDecision(
      featureKey: 'wearable_intelligence',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
  }
}
