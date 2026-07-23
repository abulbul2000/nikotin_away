import 'sleep_probe_service.dart';
import 'storage_service.dart';

/// Orchestrates the opt-in Sleep Intelligence feature: turning it on/off
/// arms or cancels the native overnight probe schedule (SleepProbeService)
/// and persists the actual window that was armed, so risk scoring
/// (StorageService._resolveEffectiveSleepWindow) reads back exactly what
/// was probed rather than recomputing it from survey fields that may have
/// changed since.
class SleepIntelligenceService {
  final StorageService _storageService;

  static const int _windowBufferMinutes = 60;
  static const int _minutesPerDay = 24 * 60;

  SleepIntelligenceService({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting('sleep_intelligence_enabled')) ==
        '1';
  }

  Future<void> enable() async {
    final sleepTimeRaw = await _storageService.loadSleepTime() ?? '23:00';
    final wakeTimeRaw =
        await _storageService.loadSetting('wake_time') ?? '07:00';
    final sleepMinute = _parseMinuteOfDay(sleepTimeRaw) ?? 23 * 60;
    final wakeMinute = _parseMinuteOfDay(wakeTimeRaw) ?? 7 * 60;

    final windowStart = _wrapMinute(sleepMinute - _windowBufferMinutes);
    final windowEnd = _wrapMinute(wakeMinute + _windowBufferMinutes);
    const interval = SleepProbeService.defaultIntervalMinutes;

    await _storageService.saveSetting('sleep_intelligence_enabled', '1');
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

    await SleepProbeService.scheduleNightlyProbing(
      windowStartMinute: windowStart,
      windowEndMinute: windowEnd,
      intervalMinutes: interval,
    );
  }

  Future<void> disable() async {
    await _storageService.saveSetting('sleep_intelligence_enabled', '0');
    await SleepProbeService.cancelNightlyProbing();
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
