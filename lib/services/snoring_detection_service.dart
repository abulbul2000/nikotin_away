import 'sleep_probe_service.dart';
import 'storage_service.dart';

/// Orchestrates the opt-in Snoring Test feature. Deliberately separate from
/// Sleep Intelligence (different consent, since this one briefly samples raw
/// audio rather than free OS metadata -- see SleepProbeReceiver.kt), but it
/// piggybacks on Sleep Intelligence's existing overnight alarm schedule
/// instead of arming its own, so it requires Sleep Intelligence to already
/// be enabled.
class SnoringDetectionService {
  final StorageService _storageService;

  /// Bump if the disclosure text this feature shows before enabling changes
  /// materially, same convention as SleepIntelligenceService.consentTextVersion.
  static const String consentTextVersion = 'v1';

  SnoringDetectionService({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting('snoring_detection_enabled')) ==
        '1';
  }

  Future<void> enable() async {
    await _storageService.saveSetting('snoring_detection_enabled', '1');
    await SleepProbeService.setSnoringDetectionEnabled(true);
    await _storageService.recordConsentDecision(
      featureKey: 'snoring_detection',
      granted: true,
      consentTextVersion: consentTextVersion,
    );
  }

  Future<void> disable() async {
    await _storageService.saveSetting('snoring_detection_enabled', '0');
    await SleepProbeService.setSnoringDetectionEnabled(false);
    await _storageService.recordConsentDecision(
      featureKey: 'snoring_detection',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
  }

  /// How many of last night's probes looked snore-like -- shown as a plain
  /// count in Settings rather than a dedicated report, matching the
  /// feature's intentionally small scope.
  Future<int> lastNightSnoreLikelyCount() {
    return _storageService.countRecentSnoreLikelyEvents();
  }
}
