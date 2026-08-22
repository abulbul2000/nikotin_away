import 'package:flutter/material.dart';

import 'sleep_probe_service.dart';
import 'snoring_detection_service.dart';
import 'notification_service.dart';
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
    if (await _isVacationActive()) {
      await SleepProbeService.cancelNightlyProbing();
      await NotificationService.cancelSleepReportNotification();
      await cancelConfiguredWakeAlarms();
      return;
    }

    final scheduleMode = await _storageService.loadSleepScheduleMode();
    final scheduleDay = scheduleMode == 'daily' ? 1 : DateTime.now().weekday;
    final configuredSleep = await _storageService.loadSleepScheduleTime(
      weekday: scheduleDay,
      wake: false,
    );
    final configuredWake = await _storageService.loadSleepScheduleTime(
      weekday: scheduleDay,
      wake: true,
    );
    final fallbackSleep = configuredSleep == null
        ? (await _storageService.loadSleepTime() ?? '23:00')
        : _formatTime(configuredSleep);
    final fallbackWake = configuredWake == null
        ? (await _storageService.loadSetting('wake_time') ?? '07:00')
        : _formatTime(configuredWake);
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
    await scheduleMorningReportForDate(DateTime.now().add(const Duration(days: 1)));
    await scheduleConfiguredWakeAlarms();
  }

  /// Schedules tomorrow's report from the day-specific answer collected in
  /// the evening routine. The legacy profile wake time remains a safe fallback
  /// for existing users who have not completed the new question yet.
  Future<void> scheduleMorningReportForDate(DateTime date) async {
    if (!await isEnabled()) return;
    if (await _isVacationActive()) return;
    final stored = await _storageService.loadWakeTimeForDate(date);
    final rawFallback = await _storageService.loadSetting('wake_time') ?? '07:00';
    final parts = rawFallback.split(':');
    final fallbackHour = int.tryParse(parts.first) ?? 7;
    final fallbackMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final wake = stored ??
        TimeOfDay(
          hour: fallbackHour.clamp(0, 23).toInt(),
          minute: fallbackMinute.clamp(0, 59).toInt(),
        );
    final wakeAt = DateTime(
      date.year,
      date.month,
      date.day,
      wake.hour,
      wake.minute,
    );
    await NotificationService.scheduleSleepReportNotification(wakeAt: wakeAt);
  }

  Future<void> scheduleConfiguredWakeAlarms() async {
    if (!await _storageService.loadWakeAlarmEnabled()) return;
    await NotificationService.cancelAllWakeAlarmNotifications();
    final mode = await _storageService.loadSleepScheduleMode();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day).add(
        Duration(days: offset),
      );
      final weekday = date.weekday;
      final configuredWake = await _storageService.loadSleepScheduleTime(
        weekday: mode == 'daily' ? 1 : weekday,
        wake: true,
      );
      final fallbackRaw = await _storageService.loadSetting('wake_time') ?? '07:00';
      final fallback = _parseTimeOfDay(fallbackRaw) ?? const TimeOfDay(hour: 7, minute: 0);
      final wake = configuredWake ?? fallback;
      await NotificationService.scheduleWakeAlarmNotification(
        wakeAt: DateTime(date.year, date.month, date.day, wake.hour, wake.minute),
        weekday: weekday,
      );
    }
  }

  Future<void> cancelConfiguredWakeAlarms() async {
    await NotificationService.cancelAllWakeAlarmNotifications();
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTimeOfDay(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
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
    await scheduleMorningReportForDate(DateTime.now().add(const Duration(days: 1)));
    await scheduleConfiguredWakeAlarms();
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
    await NotificationService.cancelSleepReportNotification();
    await _snoringDetectionService.disable();
    await _storageService.recordConsentDecision(
      featureKey: 'sleep_intelligence',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
  }

  Future<bool> _isVacationActive() async {
    final raw = await _storageService.loadSetting('sleep_vacation_until');
    if (raw == null || raw.isEmpty) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    if (until.isAfter(DateTime.now())) return true;
    await _storageService.saveSetting('sleep_vacation_until', '');
    return false;
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
