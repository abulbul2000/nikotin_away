import 'sleep_probe_service.dart';
import 'snoring_detection_service.dart';
import 'storage_service.dart';

/// Orchestrates the opt-in Sleep Intelligence feature: turning it on/off
/// arms or cancels the native overnight probe schedule (SleepProbeService)
/// and persists the actual window that was armed, so risk scoring
/// (StorageService.resolveEffectiveSleepWindow) reads back exactly what
/// was probed rather than recomputing it from survey fields that may have
/// changed since.
class SleepIntelligenceService {
  final StorageService _storageService;
  final SnoringDetectionService _snoringDetectionService;

  static const int _windowBufferMinutes = 60;
  static const int _minutesPerDay = 24 * 60;

  /// Bump when `sleepIntelligenceDescription`/`sleepIntelligencePurpose`
  /// (the disclosure text shown on the Settings card) changes materially,
  /// so the KVKK consent trail records which version of the text the user
  /// actually saw when they decided.
  static const String consentTextVersion = 'v1';

  SleepIntelligenceService({
    StorageService? storageService,
    SnoringDetectionService? snoringDetectionService,
  }) : _storageService = storageService ?? StorageService(),
       _snoringDetectionService =
           snoringDetectionService ?? SnoringDetectionService();

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting('sleep_intelligence_enabled')) ==
        '1';
  }

  /// Re-arms the overnight window when the app starts or resumes. Once the
  /// engine has a trusted recent estimate, the observed window is preferred
  /// and receives a smaller safety buffer; otherwise the user's configured
  /// sleep/wake times remain the fallback.
  Future<void> refreshScheduleIfEnabled() async {
    if (!await isEnabled()) return;

    final fallbackSleep = await _storageService.loadSleepTime() ?? '23:00';
    final fallbackWake =
        await _storageService.loadSetting('wake_time') ?? '07:00';
    final effective = await _storageService.resolveEffectiveSleepWindow(
      fallbackSleepTime: fallbackSleep,
      fallbackWakeTime: fallbackWake,
    );
    final learned =
        effective.sleepTime != fallbackSleep || effective.wakeTime != fallbackWake;
    await _armWindow(
      sleepTime: effective.sleepTime ?? fallbackSleep,
      wakeTime: effective.wakeTime ?? fallbackWake,
      bufferMinutes: learned ? 30 : _windowBufferMinutes,
    );
  }

  Future<void> enable() async {
    final sleepTimeRaw = await _storageService.loadSleepTime() ?? '23:00';
    final wakeTimeRaw =
        await _storageService.loadSetting('wake_time') ?? '07:00';
    await _storageService.saveSetting('sleep_intelligence_enabled', '1');
    await _armWindow(
      sleepTime: sleepTimeRaw,
      wakeTime: wakeTimeRaw,
      bufferMinutes: _windowBufferMinutes,
    );
    // Horlama ölçümü, Uyku Zekâsı'nın aynı gece penceresinin bir parçasıdır;
    // ayrı bir zamanlayıcı veya bağımsız kullanıcı akışı oluşturmaz.
    await _snoringDetectionService.enable();
    await _storageService.recordConsentDecision(
      featureKey: 'sleep_intelligence',
      granted: true,
      consentTextVersion: consentTextVersion,
    );
  }

  Future<void> _armWindow({
    required String sleepTime,
    required String wakeTime,
    required int bufferMinutes,
  }) async {
    final sleepMinute = _parseMinuteOfDay(sleepTime) ?? 23 * 60;
    final wakeMinute = _parseMinuteOfDay(wakeTime) ?? 7 * 60;
    final windowStart = _wrapMinute(sleepMinute - bufferMinutes);
    final windowEnd = _wrapMinute(wakeMinute + bufferMinutes);
    const interval = SleepProbeService.defaultIntervalMinutes;

    await _storageService.saveSetting(
      'sleep_probe_window_start_minute',
      windowStart.toString(),
    );
    await _storageService.saveSetting(
      'sleep_probe_window_end_minute',
      windowEnd.toString(),
    );
    await _storageService.saveSetting(
      'sleep_probe_interval_minutes',
      interval.toString(),
    );
    await _storageService.saveSetting(
      'sleep_probe_window_source',
      bufferMinutes == 30 ? 'learned' : 'configured',
    );
    await SleepProbeService.scheduleNightlyProbing(
      windowStartMinute: windowStart,
      windowEndMinute: windowEnd,
      intervalMinutes: interval,
    );
  }

  Future<void> disable() async {
    await _storageService.saveSetting('sleep_intelligence_enabled', '0');
    await SleepProbeService.cancelNightlyProbing();
    await _snoringDetectionService.disable();
    await _storageService.recordConsentDecision(
      featureKey: 'sleep_intelligence',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
  }

  int? _parseMinuteOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour.clamp(0, 23) * 60 + minute.clamp(0, 59);
  }

  int _wrapMinute(int minute) {
    final wrapped = minute % _minutesPerDay;
    return wrapped < 0 ? wrapped + _minutesPerDay : wrapped;
  }
}
